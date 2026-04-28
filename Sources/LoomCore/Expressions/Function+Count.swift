/// An SQL aggregate function that counts the number of rows or non-NULL values.
///
/// This function generates SQL's `COUNT()` aggregate function, which counts the number
/// of rows where the expression is not NULL. Can optionally count only distinct values
/// by using `COUNT(DISTINCT ...)`.
///
/// Example SQL output: `COUNT(column_name)` or `COUNT(DISTINCT column_name)`
public struct Count: Function {
  public typealias ExpressionValue = Int

  /// The expression to count.
  let expression: any Expression

  /// Whether to count only distinct values.
  let distinct: Bool

  /// Creates a new count aggregate function.
  ///
  /// - Parameters:
  ///   - expression: The expression to count.
  ///   - distinct: Whether to count only distinct values. Defaults to `false`.
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
  /// Counts the number of non-NULL values of this expression.
  ///
  /// - Parameter distinct: Whether to count only distinct values. Defaults to `false`.
  /// - Returns: A `Count` aggregate function.
  public func count(distinct: Bool = false) -> Count {
    Count(self, distinct: distinct)
  }
}
