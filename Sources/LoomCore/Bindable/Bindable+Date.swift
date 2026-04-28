import Foundation
import SQLite3

extension Date: Bindable {
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try check(sqlite3_bind_double(stmt.stmtPtr, index, value.timeIntervalSince1970), db: stmt.dbPtr, is: SQLITE_OK)
  }

  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    Date(timeIntervalSince1970: sqlite3_column_double(stmt.stmtPtr, index))
  }

  public func asSQLLiteral() throws -> String {
    "\(timeIntervalSince1970)"
  }

  public static var defaultSQLStorageType: String { "DOUBLE" }
}
