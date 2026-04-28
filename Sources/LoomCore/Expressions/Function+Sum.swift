/// SQL `SUM()` aggregate that totals all values in a group.
///
/// Wraps SQLite's `SUM()` aggregate. `ExpressionValue` is `T?` because `SUM` returns
/// `NULL` when applied to an empty set.
///
/// ```swift
/// let total = try await db.queryOne(
///   "SELECT \(Sum(ColumnExpression<Int>("amount"))) FROM \(raw: "orders") WHERE \(ColumnExpression<String>("status")) = \("paid")"
/// )
/// ```
///
/// Prefer the `sum()` method on an existing expression for readability:
///
/// ```swift
/// let amount = ColumnExpression<Int>("amount")
/// let total = amount.sum()  // SUM("amount")
/// ```
public struct Sum<T: Bindable>: Function {
  public typealias ExpressionValue = T?

  let expression: any Expression<T>

  /// Creates a `SUM()` aggregate over `expression`.
  public init(_ expression: any Expression<T>) {
    self.expression = expression
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("SUM(")
    expression.append(to: &builder)
    builder.appendLiteral(")")
  }
}

extension Expression where ExpressionValue: Bindable {
  /// Wraps this expression in a SQL `SUM()` aggregate.
  ///
  /// ```swift
  /// let price = ColumnExpression<Double>("price")
  /// let revenue = price.sum()
  /// // SQL: SUM("price")
  /// ```
  public func sum() -> Sum<ExpressionValue> {
    Sum(self)
  }
}
