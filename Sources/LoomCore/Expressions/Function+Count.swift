/// SQL `COUNT()` aggregate that counts rows or non-NULL values.
///
/// Counts rows where `expression` is not NULL, optionally restricted to distinct values
/// via `COUNT(DISTINCT ...)`.
///
/// ```swift
/// let users = ColumnExpression<String>("users", "name")
/// let total = Count(users)                    // COUNT("users"."name")
/// let unique = Count(users, distinct: true)   // COUNT(DISTINCT "users"."name")
///
/// try await db.query("SELECT \(total) FROM users") { stmt in
///   Int.column(of: stmt, at: 0)
/// }
/// ```
public struct Count: Function {
  public typealias ExpressionValue = Int

  let expression: any Expression

  let distinct: Bool

  /// Creates a `COUNT` aggregate over `expression`.
  ///
  /// Pass `distinct: true` to emit `COUNT(DISTINCT ...)`.
  public init(_ expression: any Expression, distinct: Bool = false) {
    self.expression = expression
    self.distinct = distinct
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("COUNT(")
    if distinct {
      builder.appendLiteral("DISTINCT ")
    }
    expression.append(to: &builder)
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// Wraps this expression in a `COUNT` aggregate.
  ///
  /// ```swift
  /// let email = ColumnExpression<String>("users", "email")
  /// let distinctEmails = email.count(distinct: true)
  /// // SELECT COUNT(DISTINCT "users"."email") FROM users
  /// ```
  public func count(distinct: Bool = false) -> Count {
    Count(self, distinct: distinct)
  }
}
