/// An SQL aggregate function that returns the sum of all values in a set.
///
/// This function generates SQL's `SUM()` aggregate function, which calculates the total
/// of all values in a group. The result is optional because the aggregate may be applied
/// to an empty set.
///
/// Example SQL output: `SUM(column_name)`
public struct Sum<T: Bindable>: Function {
  public typealias ExpressionValue = T?

  /// The expression to sum.
  let expression: any Expression<T>

  /// Creates a new sum aggregate function.
  ///
  /// - Parameter expression: The expression to sum.
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
  /// Returns the sum of this expression across all rows.
  ///
  /// - Returns: A `Sum` aggregate function that computes the total.
  public func sum() -> Sum<ExpressionValue> {
    Sum(self)
  }
}
