/// SQL `MIN()` aggregate, returning the smallest value in a group.
///
/// The result is optional because `MIN` over an empty set yields `NULL`.
///
/// ```swift
/// let price = ColumnExpression<Double>("price")
/// let cheapest = price.min()
/// // SELECT MIN("price") FROM "products"
/// ```
public struct Min<T: Bindable>: Function {
  public typealias ExpressionValue = T?

  let expression: any Expression<T>

  /// Wraps `expression` in a `MIN()` aggregate.
  public init(_ expression: any Expression<T>) {
    self.expression = expression
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("MIN(")
    expression.append(to: &builder)
    builder.appendLiteral(")")
  }
}

extension Expression where ExpressionValue: Bindable {
  /// Aggregates this expression with SQL `MIN()`, returning the smallest value across rows.
  ///
  /// ```swift
  /// let temperature = ColumnExpression<Double>("temperature")
  /// let coldest = temperature.min()
  /// // MIN("temperature")
  /// ```
  public func min() -> Min<ExpressionValue> {
    Min(self)
  }
}
