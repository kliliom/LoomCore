import Foundation
import SQLite3

extension Data: Bindable {
  /// Binds the bytes as a BLOB parameter, copying via `SQLITE_TRANSIENT` so the buffer can be released after the call.
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try value.withUnsafeBytes {
      try check(
        sqlite3_bind_blob(stmt.stmtPtr, index, $0.baseAddress, Int32($0.count), sqliteTransient),
        db: stmt.dbPtr,
        is: SQLITE_OK
      )
    }
  }

  /// Reads the column as a BLOB.
  ///
  /// A zero-length BLOB returns empty `Data`. Throws `LoomError.core(.nullValue, …)` when the column is `NULL` —
  /// use `Data?` if the column is nullable.
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    if let blob = sqlite3_column_blob(stmt.stmtPtr, index) {
      let count = sqlite3_column_bytes(stmt.stmtPtr, index)
      return Data(bytes: blob, count: Int(count))
    } else if sqlite3_column_type(stmt.stmtPtr, index) == SQLITE_NULL {
      throw LoomError.core(.nullValue, message: "Column at index \(index) is NULL, cannot return Data.")
    } else {
      return Data()
    }
  }

  /// Renders the bytes as an SQLite hexadecimal BLOB literal of the form `X'…'`.
  ///
  /// ```swift
  /// try Data([0xDE, 0xAD, 0xBE, 0xEF]).asSQLLiteral()  // "X'deadbeef'"
  /// ```
  public func asSQLLiteral() throws -> String {
    let hex = map { String(format: "%02x", $0) }.joined()
    return "X'\(hex)'"
  }

  /// SQLite storage class for `Data` columns: `BLOB`.
  public static var defaultSQLStorageType: String { "BLOB" }
}
