import Foundation
import SQLite3

extension Bindable where Self: RawRepresentable, RawValue: Bindable {
  /// Binds `value.rawValue` at the 1-based `index`, delegating to the raw value's `Bindable` conformance.
  ///
  /// ```swift
  /// enum Role: String, Bindable {
  ///   case admin, member, guest
  /// }
  ///
  /// try db.execute("INSERT INTO users (name, role) VALUES (\(name), \(Role.admin))")
  /// ```
  @DatabaseActor
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try RawValue.bind(to: stmt, value: value.rawValue, at: index)
  }

  /// Reads the column at the 0-based `index` as the raw value and reconstructs `Self`.
  ///
  /// Throws `LoomError.core(.typeMappingFailed, …)` when the stored raw value has no matching
  /// case — for example, when the database holds a string that no `Role` case maps to.
  @DatabaseActor
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    let rawValue = try RawValue.column(of: stmt, at: index)
    if let value = Self(rawValue: rawValue) {
      return value
    } else {
      throw LoomError.core(
        .typeMappingFailed,
        message: "Column at index \(index) could not be mapped to \(Self.self) from raw value \(rawValue)."
      )
    }
  }

  /// Renders the raw value as a SQL literal.
  public func asSQLLiteral() throws -> String {
    try rawValue.asSQLLiteral()
  }

  /// SQLite storage type inherited from `RawValue` — `TEXT` for `String`-backed enums, `INTEGER` for `Int`-backed enums.
  public static var defaultSQLStorageType: String { RawValue.defaultSQLStorageType }
}
