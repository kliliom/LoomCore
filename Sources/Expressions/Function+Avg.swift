/// An SQL aggregate function that returns the average of all values in a set.
///
/// This function generates SQL's `AVG()` aggregate function, which calculates the arithmetic
/// mean of all values in a group. The result is optional because the aggregate may be applied
/// to an empty set, and is always returned as a `Double`.
///
/// Example SQL output: `AVG(column_name)`
public struct Avg: Function {
  public typealias ExpressionValue = Double?

  /// The expression to calculate the average of.
  let expression: any Expression

  /// Creates a new average aggregate function.
  ///
  /// - Parameter expression: The expression to calculate the average of.
  public init(_ expression: any Expression) {
    self.expression = expression
  }

  public func append(to builder: inout SQLBuilder) {
    builder.sql.append("AVG(")
    expression.append(to: &builder)
    builder.sql.append(")")
  }
}

extension Expression {
  /// Returns the average value of this expression across all rows.
  ///
  /// - Returns: An `Avg` aggregate function that computes the arithmetic mean as a `Double`.
  public func avg() -> Avg {
    Avg(self)
  }
}
