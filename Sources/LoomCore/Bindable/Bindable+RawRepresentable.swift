import Foundation
import SQLite3

extension Bindable where Self: RawRepresentable, RawValue: Bindable {
  @DatabaseActor
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try RawValue.bind(to: stmt, value: value.rawValue, at: index)
  }

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

  public func asSQLLiteral() throws -> String {
    try rawValue.asSQLLiteral()
  }

  public static var defaultSQLStorageType: String { RawValue.defaultSQLStorageType }
}
