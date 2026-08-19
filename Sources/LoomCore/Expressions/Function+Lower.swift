/// SQL `LOWER()` function — converts a string to lowercase.
///
/// Wraps the SQLite `LOWER()` scalar function. Non-alphabetic characters pass through
/// unchanged, and a NULL input produces NULL.
///
/// ```swift
/// let email = ColumnExpression<String>("email")
/// let normalized = email.lower()
/// // SQL: LOWER("email")
///
/// let rows = try await db.query(
///   "SELECT id FROM users WHERE \(email.lower()) = \("alice@example.com")"
/// ) { stmt, _ in
///   try Int64.column(of: stmt, at: 0)
/// }
/// ```
public struct Lower: Function {
  public typealias ExpressionValue = String?

  let expression: any Expression

  /// Creates a `LOWER()` expression wrapping `expression`.
  public init(_ expression: any Expression) {
    self.expression = expression
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("LOWER(")
    expression.append(to: &builder)
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// Returns a `Lower` expression that lowercases this expression's value.
  ///
  /// ```swift
  /// let name = ColumnExpression<String>("name")
  /// let rows = try await db.query("SELECT id FROM users WHERE \(name.lower()) LIKE \("a%")") { stmt, _ in
  ///   try Int64.column(of: stmt, at: 0)
  /// }
  /// ```
  public func lower() -> Lower {
    Lower(self)
  }
}
