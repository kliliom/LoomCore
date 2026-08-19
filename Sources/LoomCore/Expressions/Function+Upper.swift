/// SQL `UPPER()` function — converts a string expression to uppercase.
///
/// Maps lowercase ASCII characters to uppercase; non-alphabetic characters and
/// non-ASCII letters pass through unchanged (this matches SQLite's default
/// `UPPER` behavior). Returns `nil` when the input is NULL.
///
/// ```swift
/// let name = ColumnExpression<String>("name")
/// let rows = try await db.query("SELECT \(name.upper()) FROM users") { stmt, _ in
///   try String?.column(of: stmt, at: 0)
/// }
/// // SELECT UPPER("name") FROM users
/// ```
public struct Upper: Function {
  public typealias ExpressionValue = String?

  let expression: any Expression

  /// Wraps `expression` in a SQL `UPPER(...)` call.
  public init(_ expression: any Expression) {
    self.expression = expression
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("UPPER(")
    expression.append(to: &builder)
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// Wraps this expression in a SQL `UPPER(...)` call.
  ///
  /// ```swift
  /// let email = ColumnExpression<String>("email")
  /// let normalized = email.upper()
  /// let matches = try await db.query(
  ///   "SELECT id FROM users WHERE \(normalized) = \("ALICE@EXAMPLE.COM")"
  /// ) { stmt, _ in
  ///   try Int64.column(of: stmt, at: 0)
  /// }
  /// ```
  public func upper() -> Upper {
    Upper(self)
  }
}
