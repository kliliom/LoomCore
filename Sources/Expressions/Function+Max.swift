/// An SQL aggregate function that returns the maximum value from a set of values.
///
/// This function generates SQL's `MAX()` aggregate function, which finds the largest value
/// in a group of values. The result is optional because the aggregate may be applied to an
/// empty set.
///
/// Example SQL output: `MAX(column_name)`
public struct Max<T: Bindable>: Function {
  public typealias ExpressionValue = T?

  /// The expression to find the maximum value of.
  let expression: any Expression<T>

  /// Creates a new maximum aggregate function.
  ///
  /// - Parameter expression: The expression to find the maximum value of.
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
  /// Returns the maximum value of this expression across all rows.
  ///
  /// - Returns: A `Max` aggregate function that computes the maximum value.
  public func max() -> Max<ExpressionValue> {
    Max(self)
  }
}
