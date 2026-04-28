/// Expression that applies an SQL operator to a single operand, producing prefix or postfix unary operations.
///
/// `UnaryOperation` underpins operators such as numeric negation (`-`) and logical `NOT`, as well
/// as postfix constructs like `IS NULL`. The rendered SQL is always wrapped in parentheses so
/// precedence is preserved when the expression is composed with others.
///
/// ```swift
/// let isAdult = ColumnExpression<Int>("age") >= 18
/// let isMinor = UnaryOperation<_, Bool>(operand: isAdult, sqlOperator: "NOT ")
/// // SQL: ( NOT ( "age" >= ? ) )
///
/// let balance = ColumnExpression<Double>("balance")
/// let negated = UnaryOperation<_, Double>(operand: balance, sqlOperator: "-")
/// // SQL: ( -"balance" )
/// ```
public struct UnaryOperation<Operand: Expression, Result>: Expression {
  public typealias ExpressionValue = Result

  let operand: Operand
  let sqlOperator: String
  let isPrefix: Bool

  /// Builds a unary operation around `operand`.
  ///
  /// - Parameters:
  ///   - operand: Expression the operator is applied to.
  ///   - sqlOperator: SQL token rendered adjacent to `operand`. Include any whitespace required
  ///     for valid SQL, e.g. `"NOT "` or `" IS NULL"`.
  ///   - isPrefix: When `true`, the operator is rendered before `operand`; when `false`, after.
  public init(operand: Operand, sqlOperator: String, isPrefix: Bool = true) {
    self.operand = operand
    self.sqlOperator = sqlOperator
    self.isPrefix = isPrefix
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("(")
    if isPrefix {
      builder.appendLiteral(sqlOperator)
    }
    operand.append(to: &builder)
    if !isPrefix {
      builder.appendLiteral(sqlOperator)
    }
    builder.appendLiteral(")")
  }
}
