import Foundation
import SQLite3

/// Wrapper type managing the lifecycle of a compiled SQLite statement.
///
/// This type wraps an SQLite prepared statement (`sqlite3_stmt*` pointer) and handles
/// its cleanup appropriately based on whether the statement is cached or temporary.
///
/// Prepared statements can be either:
/// - **Cached**: Retained in the database's statement cache for reuse. These are reset
///   and have their bindings cleared on deinit, but not finalized.
/// - **Temporary**: Created for one-time use. These are finalized (destroyed) on deinit.
///
/// The non-copyable constraint (`~Copyable`) ensures exclusive ownership and prevents
/// use-after-free errors or double-finalization bugs.
///
/// - Important: This type is not copyable to maintain exclusive ownership of the
///              prepared statement. Pass it using `consuming` or `borrowing` semantics.
@DatabaseActor
public struct StatementHandle: ~Copyable, Sendable {
  /// Raw SQLite database connection pointer.
  let dbPtr: OpaquePointer

  /// Raw SQLite prepared statement pointer.
  let stmtPtr: OpaquePointer

  /// Determines cleanup behavior when the handle is destroyed.
  ///
  /// - `true`: Statement is finalized (destroyed) via `sqlite3_finalize()`.
  ///           Used for temporary statements not in the cache.
  /// - `false`: Statement is reset and unbound via `sqlite3_reset()` and
  ///            `sqlite3_clear_bindings()`. Used for cached statements that
  ///            will be reused.
  let freeOnDeinit: Bool

  /// Creates a new statement handle wrapping a compiled SQLite statement.
  ///
  /// - Parameters:
  ///   - dbPtr: Raw SQLite database connection pointer.
  ///   - stmtPtr: Raw SQLite prepared statement pointer from `sqlite3_prepare_v3()`.
  ///   - freeOnDeinit: Whether to finalize (`true`) or reset (`false`) on deinit.
  init(dbPtr: OpaquePointer, stmtPtr: OpaquePointer, freeOnDeinit: Bool) {
    self.dbPtr = dbPtr
    self.stmtPtr = stmtPtr
    self.freeOnDeinit = freeOnDeinit
  }

  /// Cleans up the SQLite statement when the handle is destroyed.
  ///
  /// For temporary statements (`freeOnDeinit == true`), calls `sqlite3_finalize()`
  /// to completely destroy the statement and free its resources.
  ///
  /// For cached statements (`freeOnDeinit == false`), calls `sqlite3_reset()` to
  /// return the statement to its initial state and `sqlite3_clear_bindings()` to
  /// remove bound parameters, preparing it for reuse. The statement itself remains
  /// alive in the cache.
  ///
  /// If cleanup fails, a warning is logged but the process continues.
  deinit {
    if freeOnDeinit {
      if sqlite3_finalize(stmtPtr) != SQLITE_OK {
        let message = String(cString: sqlite3_errmsg(dbPtr))
        warn("Failed to finalize statement: \(message)")
      }
    } else {
      if sqlite3_reset(stmtPtr) != SQLITE_OK {
        let message = String(cString: sqlite3_errmsg(dbPtr))
        warn("Failed to reset statement: \(message)")
      }
      if sqlite3_clear_bindings(stmtPtr) != SQLITE_OK {
        let message = String(cString: sqlite3_errmsg(dbPtr))
        warn("Failed to clear bindings: \(message)")
      }
    }
  }
}

extension Database {
  /// Compiles an SQL statement into a prepared statement for execution.
  ///
  /// This method parses and compiles SQL into a prepared statement that can be
  /// executed with bound parameters. Prepared statements offer significant performance
  /// benefits over executing raw SQL repeatedly, as they only need to be parsed once.
  ///
  /// ## Statement Caching
  ///
  /// When the database has the ``DatabaseOptions/persistent`` option enabled, statements
  /// are automatically cached. The first call compiles the statement and stores it in the
  /// cache; subsequent calls with the same SQL string return the cached statement.
  ///
  /// Cached statements:
  /// - Are compiled with `SQLITE_PREPARE_PERSISTENT` for optimization
  /// - Are reset and have bindings cleared after use (not finalized)
  /// - Remain in the cache until the database is closed
  /// - Save parsing overhead for frequently executed queries
  ///
  /// Non-cached statements are finalized (destroyed) immediately after use.
  ///
  /// The following example demonstrates statement preparation:
  ///
  ///     let stmt = try db.prepare(sql: "SELECT * FROM users WHERE id = ?")
  ///     // Bind parameters and execute the statement...
  ///
  /// - Parameter sql: The SQL statement to compile. Must be valid SQLite syntax.
  ///
  /// - Returns: A ``StatementHandle`` wrapping the compiled statement.
  ///
  /// - Throws: `LoomError` if the SQL is invalid or if SQLite fails to prepare the statement.
  func prepare(sql: String) throws -> StatementHandle {
    let useCache = options.contains(.persistent)

    let dbPtr = try db.ptr
    if useCache, let stmtPtr = db.resourceStore.statementCache[sql] {
      return StatementHandle(
        dbPtr: dbPtr,
        stmtPtr: stmtPtr,
        freeOnDeinit: false
      )
    }

    var ptr: OpaquePointer?
    let flags: UInt32 =
      if useCache {
        UInt32(bitPattern: SQLITE_PREPARE_PERSISTENT)
      } else {
        0
      }
    try check(sqlite3_prepare_v3(dbPtr, sql, -1, flags, &ptr, nil), db: db.ptr, is: SQLITE_OK)
    guard let ptr else {
      throw LoomError.core(.unexpectedState, message: "sqlite3_prepare_v3() did not return a statement pointer.")
    }

    if useCache {
      db.resourceStore.statementCache[sql] = ptr
    }

    return StatementHandle(dbPtr: dbPtr, stmtPtr: ptr, freeOnDeinit: !useCache)
  }
}
