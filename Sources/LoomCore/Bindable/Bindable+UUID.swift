import Foundation
import SQLite3

extension UUID: Bindable {
  /// Binds the UUID as a 16-byte BLOB parameter in raw byte order (not the textual `8-4-4-4-12` form).
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try withUnsafePointer(to: value.uuid) {
      try check(sqlite3_bind_blob(stmt.stmtPtr, index, $0, 16, sqliteTransient), db: stmt.dbPtr, is: SQLITE_OK)
    }
  }

  /// Reads the column as a 16-byte BLOB — or a textual `8-4-4-4-12` UUID — and reconstructs a `UUID`.
  ///
  /// Throws `LoomError.core(.nullValue, …)` when the column is `NULL` — use `UUID?` for nullable
  /// columns — and `LoomError.core(.typeMappingFailed, …)` when the BLOB is not exactly 16 bytes,
  /// the TEXT is not a valid UUID string, or the storage class is `INTEGER` or `REAL`.
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    let storageClass = try requireStorageClass(of: stmt, at: index, oneOf: [.blob, .text], for: Self.self)
    if storageClass == SQLITE_TEXT {
      let text = try String.column(of: stmt, at: index)
      guard let uuid = UUID(uuidString: text) else {
        throw LoomError.core(
          .typeMappingFailed,
          message: "Column at index \(index) holds \"\(text)\", which is not a UUID string, cannot return UUID."
        )
      }
      return uuid
    }
    guard let blob = sqlite3_column_blob(stmt.stmtPtr, index), sqlite3_column_bytes(stmt.stmtPtr, index) == 16 else {
      try checkColumnAllocation(of: stmt)
      throw LoomError.core(
        .typeMappingFailed,
        message: "Column at index \(index) is a BLOB that is not 16 bytes, cannot return UUID."
      )
    }
    let mem = blob.bindMemory(to: uuid_t.self, capacity: 1)
    return UUID(uuid: mem.pointee)
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
