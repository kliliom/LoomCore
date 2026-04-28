/// An SQL aggregate function that concatenates values from multiple rows into a single string.
///
/// This function generates SQL's `GROUP_CONCAT()` aggregate function, which combines
/// values from multiple rows into a single comma-separated (or custom-separated) string.
/// Can optionally concatenate only distinct values. Returns `nil` when applied to an
/// empty group or when all input values are NULL.
///
/// Example SQL output: `GROUP_CONCAT(column_name)` or `GROUP_CONCAT(DISTINCT column_name, '-')`
public struct GroupConcat: Function {
  public typealias ExpressionValue = String?

  /// The expression to concatenate across rows.
  let expression: any Expression

  /// Whether to concatenate only distinct values.
  let distinct: Bool

  /// The separator to use between values. Defaults to comma.
  let separator: String?

  /// Creates a new group concatenation aggregate function.
  ///
  /// - Parameters:
  ///   - expression: The expression to concatenate across rows.
  ///   - distinct: Whether to concatenate only distinct values. Defaults to `false`.
  ///   - separator: The separator to use between values. Defaults to `","`.
  public init(_ expression: any Expression, distinct: Bool = false, separator: String? = nil) {
    self.expression = expression
    self.distinct = distinct
    self.separator = separator
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("GROUP_CONCAT(")
    if distinct {
      builder.appendLiteral("DISTINCT ")
    }
    expression.append(to: &builder)
    if let separator {
      builder.appendLiteral(", ")
      separator.append(to: &builder)
    }
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// Concatenates values of this expression from multiple rows into a single string.
  ///
  /// - Parameters:
  ///   - distinct: Whether to concatenate only distinct values. Defaults to `false`.
  ///   - separator: The separator to use between values. Defaults to `","`.
  /// - Returns: A `GroupConcat` aggregate function.
  public func groupConcat(distinct: Bool = false, separator: String? = nil) -> GroupConcat {
    GroupConcat(self, distinct: distinct, separator: separator)
  }
}
