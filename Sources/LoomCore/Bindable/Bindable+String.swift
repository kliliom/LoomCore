import Foundation
import SQLite3

extension String: Bindable {
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

  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    if let cString = sqlite3_column_text(stmt.stmtPtr, index) {
      return String(cString: cString)
    } else {
      throw LoomError.core(.nullValue, message: "Column at index \(index) is NULL, cannot return String.")
    }
  }

  public func asSQLLiteral() throws -> String {
    let escaped = replacingOccurrences(of: "'", with: "''")
    return "'\(escaped)'"
  }

  public static var defaultSQLStorageType: String { "TEXT" }
}
