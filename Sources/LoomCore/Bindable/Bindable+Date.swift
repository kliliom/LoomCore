import Foundation
import SQLite3

extension Date: Bindable {
  /// Binds the date as a `REAL` parameter holding seconds since the Unix epoch (UTC).
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try check(sqlite3_bind_double(stmt.stmtPtr, index, value.timeIntervalSince1970), db: stmt.dbPtr, is: SQLITE_OK)
  }

  /// Reads the column as a `Date` from `REAL` or `INTEGER` seconds since the Unix epoch — the
  /// representation `bind(to:value:at:)` writes.
  ///
  /// Throws `LoomError.core(.nullValue, …)` when the column is `NULL` — use `Date?` for nullable
  /// columns — and `LoomError.core(.typeMappingFailed, …)` for `TEXT` or `BLOB` storage. For
  /// columns holding SQLite datetime text (such as `TEXT DEFAULT CURRENT_TIMESTAMP`), use
  /// `TextDate`, which binds and reads that format.
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    _ = try requireStorageClass(of: stmt, at: index, oneOf: [.real, .integer], for: Self.self)
    return Date(timeIntervalSince1970: sqlite3_column_double(stmt.stmtPtr, index))
  }

  /// Renders the date as its seconds-since-epoch decimal value.
  ///
  /// ```swift
  /// try Date(timeIntervalSince1970: 1_700_000_000).asSQLLiteral()  // "1700000000.0"
  /// ```
  public func asSQLLiteral() throws -> String {
    try timeIntervalSince1970.asSQLLiteral()
  }

  /// SQLite storage type for `Date` columns: `DOUBLE`.
  public static var defaultSQLStorageType: String { "DOUBLE" }
}
