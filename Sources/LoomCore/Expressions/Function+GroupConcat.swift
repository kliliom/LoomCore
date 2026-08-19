/// SQL `GROUP_CONCAT` aggregate that joins values from grouped rows into a single string.
///
/// Combines non-NULL values from each group using `separator` (SQLite uses `,` when
/// `separator` is `nil`). With `distinct` set, repeated values collapse to one occurrence.
/// `ExpressionValue` is `String?` because the result is NULL for an empty group or when
/// every input value is NULL.
///
/// ```swift
/// // SELECT user_id, GROUP_CONCAT(DISTINCT tag, '|') AS tags
/// //   FROM user_tags
/// //  GROUP BY user_id
/// let tag = ColumnExpression<String>("tag")
/// let tags = tag.groupConcat(distinct: true, separator: "|")
/// ```
public struct GroupConcat: Function {
  public typealias ExpressionValue = String?

  let expression: any Expression

  let distinct: Bool

  let separator: String?

  /// Creates a `GROUP_CONCAT` aggregate over `expression`.
  ///
  /// - Parameters:
  ///   - expression: Expression whose values are concatenated.
  ///   - distinct: Concatenate only distinct values when `true`.
  ///   - separator: Separator written between values. When `nil`, SQLite uses `,`.
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
  /// Builds a `GROUP_CONCAT` aggregate over this expression.
  ///
  /// ```swift
  /// // SELECT author_id, GROUP_CONCAT(title, '; ') AS titles
  /// //   FROM books
  /// //  GROUP BY author_id
  /// let title = ColumnExpression<String>("title")
  /// let titles = title.groupConcat(separator: "; ")
  /// ```
  ///
  /// - Parameters:
  ///   - distinct: Concatenate only distinct values when `true`.
  ///   - separator: Separator written between values. When `nil`, SQLite uses `,`.
  public func groupConcat(distinct: Bool = false, separator: String? = nil) -> GroupConcat {
    GroupConcat(self, distinct: distinct, separator: separator)
  }
}
