/// SQL `MAX()` aggregate that returns the largest value in a group.
///
/// The result is optional because `MAX` returns `NULL` over an empty set.
///
/// ```swift
/// let users = ColumnExpression<Int>("age", in: "users")
/// let oldest = Max(users)
/// // SQL: MAX("users"."age")
/// ```
///
/// Prefer the `max()` method on `Expression` for fluent call sites:
///
/// ```swift
/// let stats = try await db.query("SELECT \(users.max()) FROM users") { row in
///   try Int?.column(of: row, at: 0)
/// }
/// ```
public struct Max<T: Bindable>: Function {
  public typealias ExpressionValue = T?

  let expression: any Expression<T>

  /// Wraps `expression` in a `MAX()` aggregate.
  public init(_ expression: any Expression<T>) {
    self.expression = expression
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("MAX(")
    expression.append(to: &builder)
    builder.appendLiteral(")")
  }
}

extension Expression where ExpressionValue: Bindable {
  /// Wraps the expression in a `MAX()` aggregate.
  ///
  /// ```swift
  /// let price = ColumnExpression<Double>("price", in: "orders")
  /// let topPrice = price.max()
  /// // SQL: MAX("orders"."price")
  /// ```
  public func max() -> Max<ExpressionValue> {
    Max(self)
  }
}
