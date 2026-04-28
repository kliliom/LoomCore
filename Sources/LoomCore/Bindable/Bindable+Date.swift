import Foundation
import SQLite3

extension Date: Bindable {
  /// Binds the date as a `REAL` parameter holding seconds since the Unix epoch (UTC).
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try check(sqlite3_bind_double(stmt.stmtPtr, index, value.timeIntervalSince1970), db: stmt.dbPtr, is: SQLITE_OK)
  }

  /// Reads the column as seconds since the Unix epoch and returns a `Date`.
  ///
  /// SQLite reports `NULL` as `0.0`, which decodes to `1970-01-01T00:00:00Z` — use `Date?` for nullable columns.
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    Date(timeIntervalSince1970: sqlite3_column_double(stmt.stmtPtr, index))
  }

  /// Renders the date as its seconds-since-epoch decimal value.
  ///
  /// ```swift
  /// try Date(timeIntervalSince1970: 1_700_000_000).asSQLLiteral()  // "1700000000.0"
  /// ```
  public func asSQLLiteral() throws -> String {
    "\(timeIntervalSince1970)"
  }

  /// SQLite storage type for `Date` columns: `DOUBLE`.
  public static var defaultSQLStorageType: String { "DOUBLE" }
}
