/// An SQL aggregate function that returns the minimum value from a set of values.
///
/// This function generates SQL's `MIN()` aggregate function, which finds the smallest value
/// in a group of values. The result is optional because the aggregate may be applied to an
/// empty set.
///
/// Example SQL output: `MIN(column_name)`
public struct Min<T: Bindable>: Function {
  public typealias ExpressionValue = T?

  /// The expression to find the minimum value of.
  let expression: any Expression<T>

  /// Creates a new minimum aggregate function.
  ///
  /// - Parameter expression: The expression to find the minimum value of.
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
  /// Returns the minimum value of this expression across all rows.
  ///
  /// - Returns: A `Min` aggregate function that computes the minimum value.
  public func min() -> Min<ExpressionValue> {
    Min(self)
  }
}
