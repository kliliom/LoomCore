import Foundation
import SQLite3

/// Owns a compiled SQLite statement and releases it when the handle goes out of scope.
///
/// Cleanup behavior depends on whether the statement came from the database's cache:
///
/// - **Cached** (`freeOnDeinit == false`): the statement is reset via `sqlite3_reset` and its bindings
///   cleared via `sqlite3_clear_bindings`, leaving it ready for reuse on the next ``Database/prepare(sql:)``
///   call with the same SQL string — unless the owning database was closed while the handle was live,
///   in which case the statement is finalized instead.
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
///   let rows = try await db.query("SELECT name, age FROM users WHERE id = \(userID)") { stmt, _ in
///     (try String.column(of: stmt, at: 0), try Int.column(of: stmt, at: 1))
///   }
/// }
/// ```
@DatabaseActor
public struct StatementHandle: ~Copyable, Sendable {
  let dbPtr: OpaquePointer

  let stmtPtr: OpaquePointer

  let freeOnDeinit: Bool

  // Set for a borrowed cached statement so `deinit` can release its checkout
  // reservation after resetting it — or finalize the statement instead when the
  // store reports the connection closed. `nil` for temporary (finalized)
  // statements.
  let store: DatabaseHandle.ResourceStore?

  init(dbPtr: OpaquePointer, stmtPtr: OpaquePointer, freeOnDeinit: Bool, store: DatabaseHandle.ResourceStore? = nil) {
    self.dbPtr = dbPtr
    self.stmtPtr = stmtPtr
    self.freeOnDeinit = freeOnDeinit
    self.store = store
  }

  deinit {
    if freeOnDeinit || store?.isClosed == true {
      // Temporary statement, or a cached one whose store was closed while this
      // handle was live: finalize. On a closed (zombie) connection this
      // finalize is what ultimately frees the connection.
      sqlite3_finalize(stmtPtr)
    } else {
      sqlite3_reset(stmtPtr)
      sqlite3_clear_bindings(stmtPtr)
      store?.checkIn(stmtPtr)
    }
  }
}

/// Bytes SQLite's tokenizer treats as inter-statement noise: whitespace and `;`.
private func isTrailingNoiseByte(_ byte: CChar) -> Bool {
  switch byte {
  case 0x20, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x3B:  // space, \t, \n, \v, \f, \r, ;
    true
  default:
    false
  }
}

extension Database {
  func prepare(sql: String, cacheable: Bool = true) throws -> StatementHandle {
    // SQLite's prepare stops at the first zero byte no matter what length is passed, so
    // anything after an embedded NUL — a second statement included — would be silently
    // dropped before the trailing-SQL check below could see it.
    guard !sql.utf8.contains(0) else {
      throw LoomError.core(
        .trailingSQL,
        message: "SQL contains an embedded NUL byte; text after it would be silently dropped."
      )
    }

    let useCache = cacheable && StatementCaching.databases.contains(ObjectIdentifier(self))

    let dbPtr = try handle.ptr
    let store = handle.resourceStore

    // Reuse a cached statement only when it isn't already borrowed by a live
    // handle. Two live handles for the same SQL are not currently expressible
    // through the public API (operations run to completion synchronously once
    // past the gate), so the checkout guard is defense in depth.
    if useCache, let stmtPtr = store.cachedStatement(for: sql), store.checkOut(stmtPtr) {
      return StatementHandle(dbPtr: dbPtr, stmtPtr: stmtPtr, freeOnDeinit: false, store: store)
    }

    var ptr: OpaquePointer?
    let flags: UInt32 =
      if useCache {
        UInt32(bitPattern: SQLITE_PREPARE_PERSISTENT)
      } else {
        0
      }
    var hasTrailingSQL = false
    try sql.withCString { cString in
      var tail: UnsafePointer<CChar>?
      try check(sqlite3_prepare_v3(dbPtr, cString, -1, flags, &ptr, &tail), db: dbPtr, is: SQLITE_OK)

      // Trailing text is benign only when SQLite itself finds no further statement in it.
      // The common shapes — "…;", "…;\n" — are pure whitespace/semicolons and are skipped
      // here without re-entering the parser. Anything else (comments included) is settled
      // by re-preparing the remainder, reusing SQLite's own tokenizer instead of
      // hand-rolling one: whitespace and comments compile to a nil statement pointer.
      if var rest = tail, rest.pointee != 0 {
        while isTrailingNoiseByte(rest.pointee) {
          rest += 1
        }
        if rest.pointee != 0 {
          var tailPtr: OpaquePointer?
          let code = sqlite3_prepare_v3(dbPtr, rest, -1, 0, &tailPtr, nil)
          if let tailPtr {
            sqlite3_finalize(tailPtr)
          }
          hasTrailingSQL = tailPtr != nil || code != SQLITE_OK
        }
      }
    }

    if hasTrailingSQL {
      // Rejected before reaching the cache, so nothing else can observe this statement.
      sqlite3_finalize(ptr)
      throw LoomError.core(
        .trailingSQL,
        message: "SQL contains more than one statement. Use `execScript(_:)` to run a multi-statement script."
      )
    }

    guard let ptr else {
      throw LoomError.core(.unexpectedState, message: "sqlite3_prepare_v3() did not return a statement pointer.")
    }

    // Cache the fresh statement only when the slot is free. When caching is on
    // but the slot is already occupied by a borrowed statement, keep this one
    // temporary so it is finalized when its handle goes out of scope.
    if useCache, store.statementCache[sql] == nil {
      store.cache(ptr, for: sql)
      _ = store.checkOut(ptr)
      return StatementHandle(dbPtr: dbPtr, stmtPtr: ptr, freeOnDeinit: false, store: store)
    }

    return StatementHandle(dbPtr: dbPtr, stmtPtr: ptr, freeOnDeinit: true)
  }
}
