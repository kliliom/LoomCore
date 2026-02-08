/// An IFNULL expression that provides a default value when an expression evaluates to NULL.
///
/// This type represents the SQL IFNULL function for handling NULL values.
///
/// Example:
/// ```swift
/// let optionalAge = ColumnExpression<Int?>("age")
/// let ageOrZero = optionalAge.ifNull(then: 0)
/// // Generates: IFNULL(age, 0)
/// ```
public struct IfNullExpression<Operand: Expression, Fallback: Expression, Result>: Expression {
  public typealias ExpressionValue = Result

  let operand: Operand
  let fallback: Fallback

  public init(operand: Operand, fallback: Fallback) {
    self.operand = operand
    self.fallback = fallback
  }

  public func append(to builder: inout SQLBuilder) {
    builder.sql.append("IFNULL(")
    operand.append(to: &builder)
    builder.sql.append(",")
    fallback.append(to: &builder)
    builder.sql.append(")")
  }
}

// MARK: - Expression Extension

extension Expression {
  /// Provides a fallback expression when the expression evaluates to NULL.
  ///
  /// This generates a SQL IFNULL expression. The result is non-optional since
  /// a fallback expression is always provided.
  ///
  /// Example:
  /// ```swift
  /// let optionalAge = ColumnExpression<Int?>("age")
  /// let defaultAge = ColumnExpression<Int>("default_age")
  /// let age = optionalAge.ifNull(defaultAge)
  /// // Generates: IFNULL(age, default_age)
  /// ```
  ///
  /// - Parameter fallbackExpr: The expression to use when the first expression is NULL.
  /// - Returns: An IFNULL expression with non-optional result type.
  public func ifNull<F: Expression, T>(_ fallbackExpr: F) -> IfNullExpression<Self, F, T>
  where ExpressionValue == T?, F.ExpressionValue == T {
    IfNullExpression(operand: self, fallback: fallbackExpr)
  }
}
