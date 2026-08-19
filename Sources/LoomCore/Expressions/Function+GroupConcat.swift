/// SQL `GROUP_CONCAT` aggregate that joins values from grouped rows into a single string.
///
/// Combines non-NULL values from each group using `separator` (SQLite uses `,` when
/// `separator` is `nil`). With `distinct` set, repeated values collapse to one occurrence.
/// `ExpressionValue` is `String?` because the result is NULL for an empty group or when
/// every input value is NULL.
///
/// SQLite rejects `GROUP_CONCAT(DISTINCT expr, sep)` — a custom separator cannot be
/// combined with `DISTINCT` — so the two options live on separate initializers and the
/// illegal combination does not compile.
///
/// ```swift
/// // SELECT user_id, GROUP_CONCAT(DISTINCT tag) AS tags
/// //   FROM user_tags
/// //  GROUP BY user_id
/// let tag = ColumnExpression<String>("tag")
/// let tags = tag.groupConcat(distinct: true)
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
  ///   - separator: Separator written between values. When `nil`, SQLite uses `,`.
  public init(_ expression: any Expression, separator: String? = nil) {
    self.expression = expression
    self.distinct = false
    self.separator = separator
  }

  /// Creates a `GROUP_CONCAT` aggregate over `expression`'s distinct values.
  ///
  /// SQLite always joins distinct values with `,` — it rejects a custom separator
  /// alongside `DISTINCT`, which is why this initializer accepts none.
  ///
  /// - Parameters:
  ///   - expression: Expression whose distinct values are concatenated.
  ///   - distinct: Concatenate only distinct values when `true`.
  public init(_ expression: any Expression, distinct: Bool) {
    self.expression = expression
    self.distinct = distinct
    self.separator = nil
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
  /// - Parameter separator: Separator written between values. When `nil`, SQLite uses `,`.
  public func groupConcat(separator: String? = nil) -> GroupConcat {
    GroupConcat(self, separator: separator)
  }

  /// Builds a `GROUP_CONCAT` aggregate over this expression's distinct values.
  ///
  /// SQLite always joins distinct values with `,` — it rejects a custom separator
  /// alongside `DISTINCT`, so use ``groupConcat(separator:)`` for custom separators.
  ///
  /// ```swift
  /// // SELECT user_id, GROUP_CONCAT(DISTINCT tag) AS tags
  /// //   FROM user_tags
  /// //  GROUP BY user_id
  /// let tag = ColumnExpression<String>("tag")
  /// let tags = tag.groupConcat(distinct: true)
  /// ```
  ///
  /// - Parameter distinct: Concatenate only distinct values when `true`.
  public func groupConcat(distinct: Bool) -> GroupConcat {
    GroupConcat(self, distinct: distinct)
  }
}
