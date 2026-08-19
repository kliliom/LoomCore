/// Membership test against a list or subquery, rendering SQL `IN` or `NOT IN`.
///
/// Evaluates to `true` when the needle matches any value in the haystack, `false` when it does
/// not, and `nil` when the needle is NULL. An empty list is rewritten to an always-false (`IN`)
/// or always-true (`NOT IN`) predicate, since `IN ()` is not valid SQLite.
///
/// ```swift
/// let status = ColumnExpression<String>("status")
/// let active = status.in(values: "active", "pending", "trial")
/// // ( "status" IN (?, ?, ?) )
///
/// let archived = status.notIn(array: ["deleted", "banned"])
/// // ( "status" NOT IN (?, ?) )
/// ```
public struct InExpression<T: Bindable>: Expression {
  public typealias ExpressionValue = Bool?

  /// The expression to test (the "needle" to search for).
  let needleExpression: any Expression

  /// The expression representing the set of values to search in (the "haystack").
  /// This can be a list of values or a subquery.
  let haystackExpression: any Expression<T>

  /// Whether this is a negated (NOT IN) expression.
  let isNegated: Bool

  /// Creates an `IN` or `NOT IN` expression from a needle and haystack.
  ///
  /// Prefer the `in(array:)`, `in(values:)`, `in(subquery:)`, and their `notIn` counterparts on
  /// `Expression` over calling this initializer directly.
  ///
  /// - Parameters:
  ///   - needleExpression: Expression to test for membership.
  ///   - haystackExpression: Set to search — a value list or a subquery.
  ///   - isNegated: Pass `true` to render `NOT IN`, `false` for `IN`.
  public init(
    needleExpression: any Expression,
    haystackExpression: any Expression<T>,
    isNegated: Bool
  ) {
    self.needleExpression = needleExpression
    self.haystackExpression = haystackExpression
    self.isNegated = isNegated
  }

  public func append(to builder: inout SQLBuilder) {
    // An empty IN list is invalid SQL in SQLite. Render an always-false (or always-true
    // for NOT IN) expression instead, preserving SQL semantics for an empty haystack.
    if let listExpr = haystackExpression as? InExpression.HaystackListExpression, listExpr.values.isEmpty {
      builder.appendLiteral("(")
      needleExpression.append(to: &builder)
      if isNegated {
        builder.appendLiteral("NOT IN (NULL) OR 1")
      } else {
        builder.appendLiteral("IN (NULL) AND 0")
      }
      builder.appendLiteral(")")
      return
    }

    needleExpression.append(to: &builder)
    if isNegated {
      builder.appendLiteral("NOT IN (")
    } else {
      builder.appendLiteral("IN (")
    }
    haystackExpression.append(to: &builder)
    builder.appendLiteral(")")
  }

  struct HaystackListExpression: Expression {
    public typealias ExpressionValue = T

    let values: [T]

    func append(to builder: inout SQLBuilder) {
      for (index, value) in values.enumerated() {
        if index > 0 {
          builder.appendLiteral(", ")
        }
        value.append(to: &builder)
      }
    }
  }
}

extension Expression {
  /// Tests whether this expression matches any value in `array`, rendering SQL `IN`.
  ///
  /// Each value is bound as a parameter, never inlined. An empty array is safe — it renders an
  /// always-false predicate rather than the invalid `IN ()`.
  ///
  /// ```swift
  /// let role = ColumnExpression<String>("role")
  /// let allowedRoles = ["admin", "editor", "owner"]
  /// let canEdit = role.in(array: allowedRoles)
  /// ```
  public func `in`<T: Bindable>(array: [T]) -> InExpression<T> {
    InExpression(
      needleExpression: self,
      haystackExpression: InExpression.HaystackListExpression(values: array),
      isNegated: false
    )
  }

  /// Tests whether this expression matches no value in `array`, rendering SQL `NOT IN`.
  ///
  /// Each value is bound as a parameter. An empty array renders an always-true predicate.
  ///
  /// ```swift
  /// let status = ColumnExpression<String>("status")
  /// let visible = status.notIn(array: ["deleted", "banned", "spam"])
  /// ```
  public func notIn<T: Bindable>(array: [T]) -> InExpression<T> {
    InExpression(
      needleExpression: self,
      haystackExpression: InExpression.HaystackListExpression(values: array),
      isNegated: true
    )
  }

  /// Tests whether this expression matches any of the variadic `values`, rendering SQL `IN`.
  ///
  /// Convenience for inline value lists; use `in(array:)` when the values come from a collection.
  ///
  /// ```swift
  /// let priority = ColumnExpression<Int>("priority")
  /// let urgent = priority.in(values: 1, 2, 3)
  /// ```
  public func `in`<T: Bindable>(values: T...) -> InExpression<T> {
    InExpression(
      needleExpression: self,
      haystackExpression: InExpression.HaystackListExpression(values: values),
      isNegated: false
    )
  }

  /// Tests whether this expression matches none of the variadic `values`, rendering SQL `NOT IN`.
  ///
  /// ```swift
  /// let category = ColumnExpression<String>("category")
  /// let nonInternal = category.notIn(values: "internal", "test", "draft")
  /// ```
  public func notIn<T: Bindable>(values: T...) -> InExpression<T> {
    InExpression(
      needleExpression: self,
      haystackExpression: InExpression.HaystackListExpression(values: values),
      isNegated: true
    )
  }

  /// Tests whether this expression matches any row produced by `subquery`, rendering SQL `IN (SELECT ...)`.
  ///
  /// The subquery must produce a single column of a type compatible with the needle.
  ///
  /// ```swift
  /// let userId = ColumnExpression<Int>("user_id")
  /// let activeUserIds = ColumnExpression<Int>("id", of: "active_users")
  /// let isActive = userId.in(subquery: activeUserIds)
  /// // ( "user_id" IN ( "active_users"."id" ) )
  /// ```
  public func `in`<T: Bindable>(subquery: any Expression<T>) -> InExpression<T> {
    InExpression(needleExpression: self, haystackExpression: subquery, isNegated: false)
  }

  /// Tests whether this expression matches no row produced by `subquery`, rendering SQL `NOT IN (SELECT ...)`.
  ///
  /// ```swift
  /// let userId = ColumnExpression<Int>("user_id")
  /// let activeUserIds = ColumnExpression<Int>("id", of: "active_users")
  /// let isInactive = userId.notIn(subquery: activeUserIds)
  /// ```
  public func notIn<T: Bindable>(subquery: any Expression<T>) -> InExpression<T> {
    InExpression(needleExpression: self, haystackExpression: subquery, isNegated: true)
  }
}
