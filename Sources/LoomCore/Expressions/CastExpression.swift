/// CAST expression that converts a value to a different SQL storage type.
///
/// Build with `Expression/cast(to:)` rather than constructing directly. The target
/// type's `Bindable/defaultSQLStorageType` determines the SQL type name emitted.
///
/// ```swift
/// // Sort numerically by an ID stored as TEXT.
/// let userID = ColumnExpression<String>("user_id")
/// let query: SQLStatement = """
///   SELECT * FROM users ORDER BY \(userID.cast(to: Int.self)) ASC
///   """
/// // ORDER BY CAST("user_id" AS INTEGER) ASC
/// ```
public struct CastExpression<Operand: Expression, Result>: Expression {
  public typealias ExpressionValue = Result

  /// The operand to which the CAST is applied.
  let operand: Operand

  /// The target SQL type to which the operand will be cast.
  let targetType: String

  /// Creates a CAST expression that converts `operand` to `targetType`.
  ///
  /// - Parameter targetType: A SQL type name such as `"INTEGER"`, `"TEXT"`, `"REAL"`,
  ///   or `"BLOB"`. Embedded directly into the generated SQL, so it must come from a
  ///   trusted source.
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
  /// Wraps the expression in a SQL `CAST(... AS <type>)`.
  ///
  /// The SQL type name comes from `Target.defaultSQLStorageType`, so casting to
  /// `Int` produces `INTEGER`, `Double` produces `DOUBLE`, `String` produces `TEXT`,
  /// and so on.
  ///
  /// ```swift
  /// // Compare a TEXT column numerically.
  /// let priceText = ColumnExpression<String>("price")
  /// let expensive = priceText.cast(to: Double.self) > 99.99
  /// // ( CAST("price" AS DOUBLE) > ? )
  /// ```
  public func cast<Target: Bindable>(to type: Target.Type) -> CastExpression<Self, Target> {
    CastExpression(operand: self, targetType: Target.defaultSQLStorageType)
  }
}
