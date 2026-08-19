/// SQL `LENGTH()` function — character count for strings, byte count for blobs.
///
/// The result is `Int?` because `LENGTH(NULL)` is NULL.
///
/// ```swift
/// let name = ColumnExpression<String>("name")
/// let users = try await db.query("SELECT \(name) FROM users WHERE \(name.length() > 10)") { stmt, _ in
///   try String.column(of: stmt, at: 0)
/// }
/// ```
///
/// Generates SQL of the form `LENGTH("name")`.
public struct Length: Function {
  public typealias ExpressionValue = Int?

  let expression: any Expression

  public init(_ expression: any Expression) {
    self.expression = expression
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("LENGTH(")
    expression.append(to: &builder)
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// Wraps this expression in SQL `LENGTH()`.
  ///
  /// ```swift
  /// let bio = ColumnExpression<String>("bio")
  /// let bioLength = bio.length()
  /// // SQL: LENGTH("bio")
  /// ```
  public func length() -> Length {
    Length(self)
  }
}
