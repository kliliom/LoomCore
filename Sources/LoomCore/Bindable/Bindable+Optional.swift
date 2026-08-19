import Foundation
import SQLite3

/// Conforms `Optional` to `Expression` so nullable values participate in expression building.
///
/// `nil` is emitted as a bound `NULL` parameter rather than a raw SQL literal, preserving
/// parameter-binding safety for absent values.
///
/// ```swift
/// let nickname: String? = nil
/// let column = ColumnExpression<String?>("nickname")
/// let ids = try await db.query("SELECT id FROM users WHERE \(column) IS \(nickname)") { stmt, _ in
///   try Int64.column(of: stmt, at: 0)
/// }
/// ```
extension Optional: Expression where Wrapped: Bindable {
  public typealias ExpressionValue = Self

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("?")
    builder.appendBinder(managedBinder)
  }
}

/// Conforms `Optional` to `Bindable` so any `Bindable` type gains nullable storage automatically.
///
/// `nil` round-trips through SQLite `NULL`; non-nil values delegate binding and column extraction
/// to the wrapped type. The default storage type is inherited from `Wrapped` — SQLite columns hold
/// `NULL` regardless of declared affinity.
///
/// ```swift
/// struct Profile {
///   var id: Int
///   var bio: String?
/// }
///
/// let profile = Profile(id: 1, bio: nil)
/// try await db.exec("UPDATE profiles SET bio = \(profile.bio) WHERE id = \(profile.id)")
/// ```
extension Optional: Bindable where Wrapped: Bindable {
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    if let value {
      try Wrapped.bind(to: stmt, value: value, at: index)
    } else {
      try check(sqlite3_bind_null(stmt.stmtPtr, index), db: stmt.dbPtr, is: SQLITE_OK)
    }
  }

  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    if sqlite3_column_type(stmt.stmtPtr, index) == SQLITE_NULL {
      .none
    } else {
      try Wrapped.column(of: stmt, at: index)
    }
  }

  public func asSQLLiteral() throws -> String {
    switch self {
    case .none:
      "NULL"
    case let .some(value):
      try value.asSQLLiteral()
    }
  }

  public static var defaultSQLStorageType: String { Wrapped.defaultSQLStorageType }
}
