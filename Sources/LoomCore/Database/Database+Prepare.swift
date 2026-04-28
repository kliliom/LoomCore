import Foundation
import SQLite3

/// Owns a compiled SQLite statement and releases it when the handle goes out of scope.
///
/// Cleanup behavior depends on whether the statement came from the database's cache:
///
/// - **Cached** (`freeOnDeinit == false`): the statement is reset via `sqlite3_reset` and its bindings
///   cleared via `sqlite3_clear_bindings`, leaving it ready for reuse on the next ``Database/prepare(sql:)``
///   call with the same SQL string.
/// - **Temporary** (`freeOnDeinit == true`): the statement is finalized via `sqlite3_finalize` and its
///   resources released.
///
/// `~Copyable` enforces exclusive ownership; pass the handle with `consuming` or `borrowing` semantics
/// to prevent double-finalization. Handles are obtained internally by the `Database` family of APIs and
/// surface to callers as a parameter to `Bindable` binding and column-extraction methods:
///
/// ```swift
/// try await db.transaction { db in
///   let userID = 42
///   let row = try db.fetchOne("SELECT name, age FROM users WHERE id = \(userID)") { stmt in
///     (try String.column(of: stmt, at: 0), try Int.column(of: stmt, at: 1))
///   }
/// }
/// ```
@DatabaseActor
public struct StatementHandle: ~Copyable, Sendable {
  let dbPtr: OpaquePointer

  let stmtPtr: OpaquePointer

  let freeOnDeinit: Bool

  init(dbPtr: OpaquePointer, stmtPtr: OpaquePointer, freeOnDeinit: Bool) {
    self.dbPtr = dbPtr
    self.stmtPtr = stmtPtr
    self.freeOnDeinit = freeOnDeinit
  }

  deinit {
    if freeOnDeinit {
      sqlite3_finalize(stmtPtr)
    } else {
      sqlite3_reset(stmtPtr)
      sqlite3_clear_bindings(stmtPtr)
    }
  }
}

extension Database {
  func prepare(sql: String) throws -> StatementHandle {
    let useCache = options.contains(.persistent)

    let dbPtr = try handle.ptr
    if useCache, let stmtPtr = handle.resourceStore.statementCache[sql] {
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
    try check(sqlite3_prepare_v3(dbPtr, sql, -1, flags, &ptr, nil), db: dbPtr, is: SQLITE_OK)
    guard let ptr else {
      throw LoomError.core(.unexpectedState, message: "sqlite3_prepare_v3() did not return a statement pointer.")
    }

    if useCache {
      handle.resourceStore.statementCache[sql] = ptr
    }

    return StatementHandle(dbPtr: dbPtr, stmtPtr: ptr, freeOnDeinit: !useCache)
  }
}
