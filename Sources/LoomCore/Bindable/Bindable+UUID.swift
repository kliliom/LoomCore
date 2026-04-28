import Foundation
import SQLite3

extension UUID: Bindable {
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try withUnsafePointer(to: value.uuid) {
      try check(sqlite3_bind_blob(stmt.stmtPtr, index, $0, 16, sqliteTransient), is: SQLITE_OK)
    }
  }

  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    if let blob = sqlite3_column_blob(stmt.stmtPtr, index), sqlite3_column_bytes(stmt.stmtPtr, index) == 16 {
      let mem = blob.bindMemory(to: uuid_t.self, capacity: 1)
      return UUID(uuid: mem.pointee)
    } else {
      throw LoomError.core(.nullValue, message: "Column at index \(index) is NULL or not 16 bytes, cannot return UUID.")
    }
  }

  public func asSQLLiteral() throws -> String {
    let bytes = withUnsafeBytes(of: uuid) { Data($0) }
    return try bytes.asSQLLiteral()
  }

  public static var defaultSQLStorageType: String { "BLOB" }
}
