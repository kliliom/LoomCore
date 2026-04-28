/// SQL `TRIM()` function that strips leading and trailing whitespace from a string.
///
/// Generates `TRIM(<expr>)`, which removes space, tab, newline, and carriage-return
/// characters from both ends of the value. The original column is not modified — the
/// result is produced per-row at query time. Returns `nil` when the input is NULL.
///
/// ```swift
/// let name = ColumnExpression<String>("name")
/// let users = try await db.query(
///   "SELECT \(name.trim()) FROM users WHERE \(name.trim()) != ''"
/// ) { String?.column(of: $0, at: 0) }
/// ```
public struct Trim: Function {
  public typealias ExpressionValue = String?

  let expression: any Expression

  /// Wraps `expression` in a SQL `TRIM()` call.
  public init(_ expression: any Expression) {
    self.expression = expression
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("TRIM(")
    expression.append(to: &builder)
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// Strips leading and trailing whitespace from this expression via SQL `TRIM()`.
  ///
  /// ```swift
  /// let email = ColumnExpression<String>("email")
  /// let normalized = email.trim()  // TRIM("email")
  /// ```
  public func trim() -> Trim {
    Trim(self)
  }
}
