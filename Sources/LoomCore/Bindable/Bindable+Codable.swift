import Foundation
import SQLite3

extension Bindable where Self: Codable {
  /// JSON-encodes `value` and binds it as a BLOB parameter at the 1-based `index`.
  ///
  /// ```swift
  /// struct Profile: Codable, Bindable {
  ///   let displayName: String
  ///   let avatarURL: URL?
  /// }
  ///
  /// try db.execute(
  ///   "INSERT INTO users (id, profile) VALUES (\(userID), \(profile))"
  /// )
  /// ```
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

  /// Reads the BLOB at the 0-based `index` and JSON-decodes it.
  ///
  /// Throws `LoomError.core(.nullValue, …)` when the column is NULL — wrap the type in
  /// `Optional` to read nullable columns.
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

  /// Renders the value as a hexadecimal BLOB literal of the form `X'…'`.
  ///
  /// Used when emitting SQL that embeds the value inline rather than via a bound parameter.
  /// Prefer parameter binding (`bind(to:value:at:)`) for anything user-supplied.
  public func asSQLLiteral() throws -> String {
    let encoder = JSONEncoder()
    let data = try encoder.encode(self)
    let hex = data.map { String(format: "%02x", $0) }.joined()
    return "X'\(hex)'"
  }

  /// `"BLOB"` — Codable values are stored as JSON-encoded blobs, not TEXT.
  public static var defaultSQLStorageType: String { "BLOB" }
}
