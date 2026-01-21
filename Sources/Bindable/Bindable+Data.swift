import Foundation
import SQLite3

extension Data: Bindable {
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try value.withUnsafeBytes {
      try check(
        sqlite3_bind_blob(stmt.stmtPtr, index, $0.baseAddress, Int32($0.count), sqliteTransient),
        is: SQLITE_OK
      )
    }
  }

  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    if let blob = sqlite3_column_blob(stmt.stmtPtr, index) {
      let count = sqlite3_column_bytes(stmt.stmtPtr, index)
      return Data(bytes: blob, count: Int(count))
    } else if sqlite3_column_type(stmt.stmtPtr, index) == SQLITE_NULL {
      throw LoomError.unexpectedNullValue
    } else {
      return Data()
    }
  }

  public func asSQLLiteral() throws -> String {
    let hex = map { String(format: "%02x", $0) }.joined()
    return "X'\(hex)'"
  }

  public static var defaultSQLStorageType: String { "BLOB" }
}
