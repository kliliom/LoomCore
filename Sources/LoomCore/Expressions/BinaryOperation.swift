/// Binary operation expression combining two operands with an SQL operator.
///
/// Represents SQL binary operations such as arithmetic (`+`, `-`, `*`, `/`),
/// comparison (`=`, `<`, `>`, `<=`, `>=`), and logical (`AND`, `OR`) operators.
/// The generated SQL is always wrapped in parentheses to preserve operator precedence
/// when nested inside larger expressions.
///
/// Build instances through the operator overloads on `Expression` rather than
/// constructing them directly:
///
/// ```swift
/// let price = ColumnExpression<Int>("price")
/// let stock = ColumnExpression<Int>("stock")
///
/// let inStockBudget = (price <= 100) && (stock > 0)
/// let rows = try await db.query("SELECT name FROM products WHERE \(inStockBudget)") { stmt, _ in
///   try String.column(of: stmt, at: 0)
/// }
/// ```
public struct BinaryOperation<Left: Expression, Right: Expression, Result>: Expression {
  public typealias ExpressionValue = Result

  let left: Left

  let right: Right

  let sqlOperator: String

  /// Creates a binary operation from two operands and an SQL operator token.
  ///
  /// - Parameters:
  ///   - left: Left-hand operand.
  ///   - right: Right-hand operand.
  ///   - sqlOperator: The literal operator emitted between the operands
  ///     (e.g. `"+"`, `"="`, `"AND"`). Inserted verbatim, so it must be a trusted,
  ///     non-user-controlled string.
  public init(left: Left, right: Right, sqlOperator: String) {
    self.left = left
    self.right = right
    self.sqlOperator = sqlOperator
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("(")
    left.append(to: &builder)
    builder.appendLiteral(sqlOperator)
    right.append(to: &builder)
    builder.appendLiteral(")")
  }
}
