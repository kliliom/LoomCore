import Foundation
import SQLite3

/// Opt-in JSON-as-`TEXT` storage for `Codable` types.
///
/// Conforming a `Codable` type gives it a complete ``Bindable`` implementation with no
/// members to write: values are JSON-encoded on bind and JSON-decoded on column reads.
///
/// ```swift
/// struct Profile: Codable, JSONBindable {
///   let displayName: String
///   let avatarURL: URL?
/// }
///
/// let userID = 1
/// let profile = Profile(displayName: "Alice", avatarURL: nil)
/// try await db.exec("INSERT INTO users (id, profile) VALUES (\(userID), \(profile))")
/// ```
///
/// JSON storage is opt-in rather than automatic for every `Codable` ``Bindable`` so the
/// two never compete: a raw-value enum declared `enum Role: String, Codable, Bindable`
/// keeps its raw-value storage (`'admin'`, not `'"admin"'`) with no ambiguity. For the
/// same reason, never combine `JSONBindable` with a `RawRepresentable`-based `Bindable`
/// conformance on one type — the two sets of default witnesses collide.
public protocol JSONBindable: Bindable, Codable {}

extension JSONBindable {
  /// JSON-encodes `value` and binds it as a `TEXT` parameter at the 1-based `index`.
  ///
  /// Storing JSON as `TEXT` keeps the value directly usable with SQLite's JSON functions
  /// (`json_extract`, `->`, `->>`, `json_set`, …) on every SQLite version.
  @DatabaseActor
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    let encoder = JSONEncoder()
    let data = try encoder.encode(value)
    try data.withUnsafeBytes {
      try check(
        sqlite3_bind_text(stmt.stmtPtr, index, $0.baseAddress, Int32($0.count), sqliteTransient),
        db: stmt.dbPtr,
        is: SQLITE_OK
      )
    }
  }

  /// Reads the TEXT (or BLOB, written by earlier LoomCore versions) at the 0-based `index`
  /// and JSON-decodes it.
  ///
  /// Throws `LoomError.core(.nullValue, …)` when the column is NULL — wrap the type in
  /// `Optional` to read nullable columns — and `LoomError.core(.typeMappingFailed, …)`
  /// for `INTEGER` or `REAL` storage or an empty payload. Malformed JSON propagates the
  /// decoder's `DecodingError`.
  @DatabaseActor
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    _ = try requireStorageClass(of: stmt, at: index, oneOf: [.blob, .text], for: Self.self)
    guard let blob = sqlite3_column_blob(stmt.stmtPtr, index) else {
      try checkColumnAllocation(of: stmt)
      throw LoomError.core(
        .typeMappingFailed,
        message: "Column at index \(index) is empty, which is not valid JSON, cannot return \(Self.self)."
      )
    }
    let data = Data(bytes: blob, count: Int(sqlite3_column_bytes(stmt.stmtPtr, index)))
    let decoder = JSONDecoder()
    return try decoder.decode(Self.self, from: data)
  }

  /// Renders the value as a single-quoted SQL string literal holding its JSON encoding.
  ///
  /// Used when emitting SQL that embeds the value inline rather than via a bound parameter.
  /// Prefer parameter binding (`bind(to:value:at:)`) for anything user-supplied.
  public func asSQLLiteral() throws -> String {
    let encoder = JSONEncoder()
    let data = try encoder.encode(self)
    return try String(decoding: data, as: UTF8.self).asSQLLiteral()
  }

  /// `"TEXT"` — Codable values are stored as JSON text, ready for SQLite's JSON functions.
  public static var defaultSQLStorageType: String { "TEXT" }
}
