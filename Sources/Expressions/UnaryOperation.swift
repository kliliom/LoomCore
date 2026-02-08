/// A unary operation expression that applies an SQL operator to a single operand.
///
/// This type represents SQL unary operations like negation (`-`) and logical NOT (`NOT`).
///
/// Example:
/// ```swift
/// let value = ColumnExpression<Int>("value")
/// let negated = -value  // UnaryOperation<ColumnExpression<Int>, Int>
/// ```
public struct UnaryOperation<Operand: Expression, Result>: Expression {
  public typealias ExpressionValue = Result

  /// The operand to which the unary operator is applied.
  let operand: Operand

  /// The SQL operator to apply (e.g., "-", "NOT").
  let sqlOperator: String

  /// Indicates whether the operator is a prefix (e.g., `-value`) or postfix (e.g., `value IS NULL`).
  let isPrefix: Bool

  public init(operand: Operand, sqlOperator: String, isPrefix: Bool = true) {
    self.operand = operand
    self.sqlOperator = sqlOperator
    self.isPrefix = isPrefix
  }

  public func append(to builder: inout SQLBuilder) {
    builder.sql.append("(")
    if isPrefix {
      builder.sql.append(sqlOperator)
    }
    operand.append(to: &builder)
    if !isPrefix {
      builder.sql.append(sqlOperator)
    }
    builder.sql.append(")")
  }
}
