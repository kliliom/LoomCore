import Foundation
import SQLite3

extension Bindable where Self: Codable {
  @DatabaseActor
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    let encoder = JSONEncoder()
    let data = try encoder.encode(value)
    try data.withUnsafeBytes {
      try check(
        sqlite3_bind_blob(stmt.stmtPtr, index, $0.baseAddress, Int32($0.count), sqliteTransient),
        db: stmt.dbPtr,
        is: SQLITE_OK
      )
    }
  }

  @DatabaseActor
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    if let blob = sqlite3_column_blob(stmt.stmtPtr, index) {
      let count = sqlite3_column_bytes(stmt.stmtPtr, index)
      let data = Data(bytes: blob, count: Int(count))
      let decoder = JSONDecoder()
      return try decoder.decode(Self.self, from: data)
    } else {
      throw LoomError.core(.nullValue, message: "Column at index \(index) is NULL, cannot decode to \(Self.self).")
    }
  }

  public func asSQLLiteral() throws -> String {
    let encoder = JSONEncoder()
    let data = try encoder.encode(self)
    let hex = data.map { String(format: "%02x", $0) }.joined()
    return "X'\(hex)'"
  }

  public static var defaultSQLStorageType: String { "BLOB" }
}
