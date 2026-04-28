/// SQL `IFNULL(operand, fallback)` expression that substitutes a fallback when the operand is NULL.
///
/// Use ``Expression/ifNull(_:)`` or the convenience overloads on optional columns to construct values
/// of this type. The `Result` type is non-optional because the fallback guarantees a non-NULL value.
///
/// ```swift
/// struct UserRow {
///   let name: String
///   let displayName: String
/// }
///
/// let name = ColumnExpression<String>("name")
/// let nickname = ColumnExpression<String?>("nickname")
///
/// let rows = try database.query(
///   """
///   SELECT \(name), \(nickname.ifNull(name)) AS display_name FROM users
///   """,
///   rowMapper: { stmt, index in
///     UserRow(
///       name: try String.column(of: stmt, at: &index),
///       displayName: try String.column(of: stmt, at: &index)
///     )
///   }
/// )
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
    builder.appendLiteral("IFNULL(")
    operand.append(to: &builder)
    builder.appendLiteral(",")
    fallback.append(to: &builder)
    builder.appendLiteral(")")
  }
}

// MARK: - Expression Extension

extension Expression {
  /// Substitutes `fallbackExpr` when this expression evaluates to NULL, producing a non-optional result.
  ///
  /// Available on optional expressions whose unwrapped type matches the fallback's value type.
  /// The returned ``IfNullExpression`` renders as `IFNULL(self, fallbackExpr)`.
  ///
  /// ```swift
  /// let nickname = ColumnExpression<String?>("nickname")
  /// let username = ColumnExpression<String>("username")
  /// let displayName = nickname.ifNull(username)
  ///
  /// let names = try database.query(
  ///   "SELECT \(displayName) FROM users ORDER BY \(username)",
  ///   rowMapper: { stmt, index in try String.column(of: stmt, at: &index) }
  /// )
  /// ```
  public func ifNull<F: Expression, T>(_ fallbackExpr: F) -> IfNullExpression<Self, F, T>
  where ExpressionValue == T?, F.ExpressionValue == T {
    IfNullExpression(operand: self, fallback: fallbackExpr)
  }
}
