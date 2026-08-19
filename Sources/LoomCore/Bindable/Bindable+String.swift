import Foundation
import SQLite3

extension String: Bindable {
  /// Binds the UTF-8 bytes as a `TEXT` parameter via `sqlite3_bind_text`, copying with `SQLITE_TRANSIENT`.
  ///
  /// Tries the contiguous-storage fast path first; falls back to materializing UTF-8 into a temporary buffer
  /// when the storage isn't already contiguous.
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    let success = try value.utf8.withContiguousStorageIfAvailable { ptr in
      try check(
        sqlite3_bind_text(stmt.stmtPtr, index, ptr.baseAddress, Int32(ptr.count), sqliteTransient),
        db: stmt.dbPtr,
        is: SQLITE_OK
      )
      return SQLITE_OK
    }
    if let success, success == SQLITE_OK {
      return
    }

    var copy = value
    try copy.withUTF8 { ptr in
      try check(
        sqlite3_bind_text(stmt.stmtPtr, index, ptr.baseAddress, Int32(ptr.count), sqliteTransient),
        db: stmt.dbPtr,
        is: SQLITE_OK
      )
    }
  }

  /// Reads the column as UTF-8 `TEXT`, using the column's byte count so embedded NUL bytes round-trip.
  ///
  /// Throws `LoomError.core(.nullValue, …)` when the column is `NULL` — use `String?` for nullable
  /// columns — and `LoomError.core(.typeMappingFailed, …)` when the storage class is not `TEXT`.
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    _ = try requireStorageClass(of: stmt, at: index, oneOf: .text, for: Self.self)
    // SQLite requires calling sqlite3_column_text before sqlite3_column_bytes.
    guard let text = sqlite3_column_text(stmt.stmtPtr, index) else {
      try checkColumnAllocation(of: stmt)
      return ""
    }
    let count = Int(sqlite3_column_bytes(stmt.stmtPtr, index))
    return String(decoding: UnsafeBufferPointer(start: text, count: count), as: UTF8.self)
  }

  /// Renders the value as a single-quoted SQL string literal, doubling embedded single quotes.
  ///
  /// ```swift
  /// try "Alice".asSQLLiteral()    // "'Alice'"
  /// try "O'Brien".asSQLLiteral()  // "'O''Brien'"
  /// ```
  public func asSQLLiteral() throws -> String {
    "'\(doublingOccurrences(of: "'"))'"
  }

  /// SQLite storage type for `String` columns: `TEXT`.
  public static var defaultSQLStorageType: String { "TEXT" }
}
