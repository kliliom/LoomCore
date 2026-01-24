@testable import LoomCore

// Helper struct to create column reference expressions for testing
struct ColumnExpression<T>: LoomCore.Expression {
  typealias ExpressionValue = T

  let columnName: String

  init(_ columnName: String) {
    self.columnName = columnName
  }

  func append(to builder: inout SQLBuilder) {
    builder.sql.append(columnName)
  }
}
