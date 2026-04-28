import Foundation
import SQLite3

extension UUID: Bindable {
  /// Binds the UUID as a 16-byte BLOB parameter in raw byte order (not the textual `8-4-4-4-12` form).
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try withUnsafePointer(to: value.uuid) {
      try check(sqlite3_bind_blob(stmt.stmtPtr, index, $0, 16, sqliteTransient), db: stmt.dbPtr, is: SQLITE_OK)
    }
  }

  /// Reads the column as a 16-byte BLOB and reconstructs a `UUID`.
  ///
  /// Throws `LoomError.core(.nullValue, …)` when the column is `NULL` or its byte length is not exactly 16 — use
  /// `UUID?` for nullable columns, and avoid mixing this representation with text-encoded UUIDs in the same column.
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    if let blob = sqlite3_column_blob(stmt.stmtPtr, index), sqlite3_column_bytes(stmt.stmtPtr, index) == 16 {
      let mem = blob.bindMemory(to: uuid_t.self, capacity: 1)
      return UUID(uuid: mem.pointee)
    } else {
      throw LoomError.core(.nullValue, message: "Column at index \(index) is NULL or not 16 bytes, cannot return UUID.")
    }
  }

  /// Renders the UUID as a 16-byte SQLite hexadecimal BLOB literal of the form `X'…'`.
  ///
  /// ```swift
  /// try UUID(uuidString: "00112233-4455-6677-8899-AABBCCDDEEFF")!.asSQLLiteral()
  /// // "X'00112233445566778899aabbccddeeff'"
  /// ```
  public func asSQLLiteral() throws -> String {
    let bytes = withUnsafeBytes(of: uuid) { Data($0) }
    return try bytes.asSQLLiteral()
  }

  /// SQLite storage class for `UUID` columns: `BLOB`.
  public static var defaultSQLStorageType: String { "BLOB" }
}
