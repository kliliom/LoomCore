import SQLite3

/// Wrapper type for a handle to an SQLite database connection.
///
/// This type manages the lifetime of an SQLite database connection (`sqlite3*` pointer)
/// and its associated resources such as cached prepared statements. It uses Swift's
/// non-copyable types (`~Copyable`) to ensure exclusive ownership and prevent
/// use-after-free errors or double-close bugs.
///
/// When this handle is deinitialized, all cached prepared statements are finalized
/// and the database connection is closed. Cleanup is dispatched to ``DatabaseActor``
/// to ensure it runs in the correct isolation context.
///
/// - Important: This type is not copyable to maintain exclusive ownership of the
///              database connection. Pass it using `consuming` or `borrowing` semantics.
@DatabaseActor
public struct DatabaseHandle: ~Copyable, Sendable {
  /// Raw SQLite database connection pointer.
  private var ptrRaw: OpaquePointer?

  /// Returns the raw SQLite database connection pointer.
  ///
  /// - Throws: `LoomError` with code `.databaseClosed` if the connection has already been closed.
  var ptr: OpaquePointer {
    get throws {
      guard let ptrRaw else {
        throw LoomError.core(.databaseClosed, message: "Database connection closed.")
      }
      return ptrRaw
    }
  }

  /// Shared resource store that owns cached prepared statements.
  ///
  /// This reference-type store allows resources to be transferred to an
  /// actor-isolated ``Task`` during `deinit` for safe cleanup.
  let resourceStore = ResourceStore()

  /// Creates a new database handle wrapping an SQLite connection.
  ///
  /// - Parameter ptr: Raw SQLite database connection pointer from `sqlite3_open()`.
  init(ptr: OpaquePointer) {
    self.ptrRaw = ptr
  }

  /// Schedules cleanup of all database resources when the handle is destroyed.
  ///
  /// Because `deinit` on a `@DatabaseActor`-isolated struct may run off-actor,
  /// the actual cleanup (statement finalization and connection close) is dispatched
  /// to ``DatabaseActor`` via a ``Task``. Both the raw pointer and the resource
  /// store are captured by value to ensure they remain valid.
  deinit {
    Task { @DatabaseActor [ptrRaw, resourceStore] in
      resourceStore.close(dbPtr: ptrRaw)
    }
  }

  /// Explicitly closes the database connection and finalizes all cached statements.
  ///
  /// After calling this method, any subsequent attempt to access ``ptr`` will throw.
  /// This allows eager resource release without waiting for `deinit`. The `deinit`
  /// cleanup becomes a no-op because ``ptrRaw`` is set to `nil`.
  mutating func kill() {
    resourceStore.close(dbPtr: ptrRaw)
    ptrRaw = nil
  }
}

extension DatabaseHandle {
  /// Internal storage for database resources that must outlive the ``DatabaseHandle`` struct.
  ///
  /// This class exists because `DatabaseHandle` is a non-copyable struct whose `deinit`
  /// may run on an arbitrary thread. By storing resources in a reference type, they can
  /// be safely captured and moved into an actor-isolated ``Task`` for cleanup.
  @DatabaseActor
  final class ResourceStore: Sendable {
    /// Cache of compiled SQL statements for reuse.
    ///
    /// Maps SQL strings to their compiled statement pointers. Cached statements are
    /// finalized when ``close(dbPtr:)`` is called during database shutdown.
    var statementCache: [String: OpaquePointer] = [:]

    /// Finalizes all cached statements and closes the database connection.
    ///
    /// This method first finalizes every cached prepared statement, then clears
    /// the cache, and finally closes the SQLite connection. If closing fails,
    /// a warning is logged.
    ///
    /// - Parameter dbPtr: The raw SQLite database connection pointer to close.
    consuming func close(dbPtr: OpaquePointer?) {
      for (_, stmtPtr) in statementCache {
        sqlite3_finalize(stmtPtr)
      }
      statementCache = [:]

      if let dbPtr, sqlite3_close(dbPtr) != SQLITE_OK {
        let message = String(cString: sqlite3_errmsg(dbPtr))
        warn("Failed to close database: \(message)")
      }
    }
  }
}
