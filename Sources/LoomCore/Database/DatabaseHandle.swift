import SQLite3

/// Owns an open SQLite connection and its cached prepared statements.
///
/// `DatabaseHandle` is non-copyable to enforce exclusive ownership of the underlying
/// `sqlite3*` pointer. When the handle is destroyed, idle cached statements are
/// finalized and the connection is closed via `sqlite3_close_v2`; statements still
/// borrowed by a live `StatementHandle` are finalized by that handle's `deinit`,
/// which frees the zombie connection. Because `deinit` may run off-actor, cleanup
/// is dispatched to `DatabaseActor` via a `Task`.
///
/// Pass instances using `consuming` or `borrowing` parameters rather than copying.
@DatabaseActor
public struct DatabaseHandle: ~Copyable, Sendable {
  // Raw SQLite database connection pointer; `nil` after `close()`.
  private var ptrRaw: OpaquePointer?

  // Throws `LoomError(.databaseClosed)` once the connection has been closed.
  var ptr: OpaquePointer {
    get throws {
      guard let ptrRaw else {
        throw LoomError.core(.databaseClosed, message: "Database connection closed.")
      }
      return ptrRaw
    }
  }

  // Reference-type store so cached statements can be captured by value into
  // the deinit cleanup `Task`.
  let resourceStore = ResourceStore()

  init(ptr: OpaquePointer) {
    self.ptrRaw = ptr
  }

  // `deinit` may run off-actor, so cleanup hops onto `DatabaseActor`.
  // Both the pointer and the resource store are captured by value.
  deinit {
    Task { @DatabaseActor [ptrRaw, resourceStore] in
      resourceStore.close(dbPtr: ptrRaw)
    }
  }

  // Eagerly closes the connection; idle cached statements are finalized
  // immediately, borrowed ones when their handles are destroyed. After this
  // returns, `ptr` throws and the `deinit` cleanup becomes a no-op.
  mutating func close() {
    resourceStore.close(dbPtr: ptrRaw)
    ptrRaw = nil
  }
}

extension DatabaseHandle {
  // Reference-type backing store for resources that must outlive the
  // non-copyable `DatabaseHandle` struct so they can be moved into the
  // deinit cleanup `Task`.
  @DatabaseActor
  final class ResourceStore: Sendable {
    var statementCache: [String: OpaquePointer] = [:]

    // Cached statements currently borrowed by a live `StatementHandle`. A
    // borrowed statement must not be handed out again — two live handles over
    // one `sqlite3_stmt` would share a single cursor, so the inner handle's
    // reset would corrupt the outer handle's in-flight iteration.
    //
    // `nonisolated(unsafe)`: mutated from `Database/prepare(sql:)` (actor
    // isolated) and from `StatementHandle.deinit`, which the compiler models as
    // nonisolated. Both run on ``DatabaseActor`` at runtime — the deinit already
    // relies on this to call `sqlite3_reset` — so access is serialized in fact.
    nonisolated(unsafe) var checkedOut: Set<OpaquePointer> = []

    // Set once `close(dbPtr:)` has run; never reset.
    //
    // `nonisolated(unsafe)`: written from `close(dbPtr:)` (actor isolated) and
    // read from `StatementHandle.deinit`, which the compiler models as
    // nonisolated. Both run on ``DatabaseActor`` at runtime — the same
    // serialization `checkedOut` already relies on.
    nonisolated(unsafe) private(set) var isClosed = false

    // Marks a cached statement as borrowed; returns `false` if it was already
    // checked out, signalling that the caller must not reuse it.
    nonisolated func checkOut(_ stmtPtr: OpaquePointer) -> Bool {
      checkedOut.insert(stmtPtr).inserted
    }

    // Releases a borrowed cached statement so it can be reused.
    nonisolated func checkIn(_ stmtPtr: OpaquePointer) {
      checkedOut.remove(stmtPtr)
    }

    // Finalizes idle cached statements, marks the store closed, and closes the
    // SQLite connection via `sqlite3_close_v2`. A failed close (misuse-only
    // with `_v2`) is logged as a warning.
    //
    // Statements currently checked out are skipped: their `StatementHandle`s
    // are still live (`Database/close()` is callable from inside a stepper),
    // and finalizing them here would leave those handles resetting freed
    // memory. `sqlite3_close_v2` tolerates the stragglers — the connection
    // becomes a zombie that SQLite frees when the last surviving statement is
    // finalized by its handle's `deinit`, which consults `isClosed`.
    consuming func close(dbPtr: OpaquePointer?) {
      guard !isClosed else { return }
      isClosed = true

      for (_, stmtPtr) in statementCache where !checkedOut.contains(stmtPtr) {
        sqlite3_finalize(stmtPtr)
      }
      statementCache = [:]
      checkedOut = []

      if let dbPtr {
        let rc = sqlite3_close_v2(dbPtr)
        if rc != SQLITE_OK {
          let message = String(cString: sqlite3_errstr(rc))
          warn("Failed to close database: \(message)")
        }
      }
    }
  }
}
