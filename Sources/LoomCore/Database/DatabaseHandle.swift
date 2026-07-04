import SQLite3

/// Owns an open SQLite connection and its cached prepared statements.
///
/// `DatabaseHandle` is non-copyable to enforce exclusive ownership of the underlying
/// `sqlite3*` pointer. When the handle is destroyed, every cached statement is
/// finalized and the connection is closed; because `deinit` may run off-actor,
/// cleanup is dispatched to `DatabaseActor` via a `Task`.
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

  // Eagerly closes the connection and finalizes cached statements. After this
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

    // Marks a cached statement as borrowed; returns `false` if it was already
    // checked out, signalling that the caller must not reuse it.
    nonisolated func checkOut(_ stmtPtr: OpaquePointer) -> Bool {
      checkedOut.insert(stmtPtr).inserted
    }

    // Releases a borrowed cached statement so it can be reused.
    nonisolated func checkIn(_ stmtPtr: OpaquePointer) {
      checkedOut.remove(stmtPtr)
    }

    // Finalizes every cached statement, clears the cache, and closes the
    // SQLite connection. A failed `sqlite3_close` is logged as a warning.
    consuming func close(dbPtr: OpaquePointer?) {
      for (_, stmtPtr) in statementCache {
        sqlite3_finalize(stmtPtr)
      }
      statementCache = [:]
      checkedOut = []

      if let dbPtr {
        let rc = sqlite3_close(dbPtr)
        if rc != SQLITE_OK {
          let message = String(cString: sqlite3_errstr(rc))
          warn("Failed to close database: \(message)")
        }
      }
    }
  }
}
