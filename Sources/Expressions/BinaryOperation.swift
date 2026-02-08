/// A binary operation expression that combines two operands with an SQL operator.
///
/// This type represents SQL binary operations like arithmetic (`+`, `-`, `*`, `/`),
/// comparison (`=`, `<`, `>`), and logical (`AND`, `OR`) operations.
///
/// Example:
/// ```swift
/// let price = ColumnExpression<Int>("price")
/// let minPrice = 100
/// let condition = price > minPrice  // BinaryOperation<ColumnExpression<Int>, Int, Bool?>
/// ```
public struct BinaryOperation<Left: Expression, Right: Expression, Result>: Expression {
  public typealias ExpressionValue = Result

  /// The left-hand side expression.
  let left: Left

  /// The right-hand side expression.
  let right: Right

  /// The SQL operator to apply (e.g., "+", "=", "AND").
  let sqlOperator: String

  public init(left: Left, right: Right, sqlOperator: String) {
    self.left = left
    self.right = right
    self.sqlOperator = sqlOperator
  }

  public func append(to builder: inout SQLBuilder) {
    builder.sql.append("(")
    left.append(to: &builder)
    builder.sql.append(sqlOperator)
    right.append(to: &builder)
    builder.sql.append(")")
  }
}
