/// A CAST expression that converts a value to a different SQL type.
///
/// This type represents SQL CAST operations for type conversion.
///
/// Example:
/// ```swift
/// let stringValue = ColumnExpression<String>("user_id")
/// let intValue = stringValue.cast(to: Int.self)
/// // Generates: CAST(user_id AS INTEGER)
/// ```
public struct CastExpression<Operand: Expression, Result>: Expression {
  public typealias ExpressionValue = Result

  /// The operand to which the CAST is applied.
  let operand: Operand

  /// The target SQL type to which the operand will be cast.
  let targetType: String

  public init(operand: Operand, targetType: String) {
    self.operand = operand
    self.targetType = targetType
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("CAST(")
    operand.append(to: &builder)
    builder.appendLiteral("AS \(targetType))")
  }
}

// MARK: - Expression Extension

extension Expression {
  /// Casts the expression to a different SQL type.
  ///
  /// This generates a SQL CAST expression to convert the value to the target type.
  ///
  /// Example:
  /// ```swift
  /// let stringValue = ColumnExpression<String>("user_id")
  /// let intValue = stringValue.cast(to: Int.self)
  /// // Generates: CAST(user_id AS INTEGER)
  /// ```
  ///
  /// - Parameter type: The target type to which the expression should be cast. This must conform to `Bindable` to determine the appropriate SQL storage type.
  /// - Returns: A cast expression with the target type.
  public func cast<Target: Bindable>(to type: Target.Type) -> CastExpression<Self, Target> {
    CastExpression(operand: self, targetType: Target.defaultSQLStorageType)
  }
}
