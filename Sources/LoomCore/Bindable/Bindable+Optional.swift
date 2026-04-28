import Foundation
import SQLite3

extension Optional: Expression where Wrapped: Bindable {
  public typealias ExpressionValue = Self

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("?")
    builder.appendBinder(managedBinder)
  }
}

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
