/// SQL `AVG()` aggregate that returns the arithmetic mean of values in a group.
///
/// Result is `Double?` — SQLite returns `NULL` when the aggregate is applied to an empty
/// set or a group containing only `NULL` values.
///
/// ```swift
/// let orders = ColumnExpression<Int>("amount", of: "orders")
/// let avgAmount = orders.avg()
/// // SQL: AVG("orders"."amount")
///
/// let rows = try await db.query("SELECT \(avgAmount) FROM orders") { stmt, _ in
///   try Double?.column(of: stmt, at: 0)
/// }
/// ```
public struct Avg: Function {
  public typealias ExpressionValue = Double?

  let expression: any Expression

  /// Creates an `AVG()` aggregate over `expression`.
  public init(_ expression: any Expression) {
    self.expression = expression
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("AVG(")
    expression.append(to: &builder)
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// Wraps this expression in an `AVG()` aggregate.
  ///
  /// ```swift
  /// let salary = ColumnExpression<Int>("salary", of: "employees")
  /// let department = ColumnExpression<String>("department", of: "employees")
  ///
  /// let stmt: SQLStatement = """
  ///   SELECT \(department), \(salary.avg())
  ///   FROM employees
  ///   GROUP BY \(department)
  ///   """
  /// ```
  public func avg() -> Avg {
    Avg(self)
  }
}
