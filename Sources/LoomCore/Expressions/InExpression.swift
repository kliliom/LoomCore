/// An SQL expression that tests whether a value is in (or not in) a set of values or subquery.
///
/// This expression generates SQL's `IN` or `NOT IN` operator, which checks if a value matches
/// (or does not match) any value in a list or subquery result. The result is a boolean: `true`
/// if the condition matches, `false` otherwise, or `nil` if the needle expression is NULL.
///
/// Example SQL output:
/// - List: `column_name IN (?, ?, ?)` or `column_name NOT IN (?, ?, ?)`
/// - Subquery: `column_name IN (SELECT ...)` or `column_name NOT IN (SELECT ...)`
public struct InExpression<T: Bindable>: Expression {
  public typealias ExpressionValue = Bool?

  /// The expression to test (the "needle" to search for).
  let needleExpression: any Expression

  /// The expression representing the set of values to search in (the "haystack").
  /// This can be a list of values or a subquery.
  let haystackExpression: any Expression<T>

  /// Whether this is a negated (NOT IN) expression.
  let isNegated: Bool

  /// Creates a new IN or NOT IN expression.
  ///
  /// - Parameters:
  ///   - needleExpression: The expression to test.
  ///   - haystackExpression: The expression representing the set of values (list or subquery).
  ///   - isNegated: Whether this is a NOT IN expression. Defaults to `false`.
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
    needleExpression.append(to: &builder)
    if isNegated {
      builder.appendLiteral("NOT IN (")
    } else {
      builder.appendLiteral("IN (")
    }
    haystackExpression.append(to: &builder)
    builder.appendLiteral(")")
  }

  /// An internal expression type that represents a list of values for the IN clause.
  ///
  /// This type handles rendering a comma-separated list of bound parameters
  /// for use in IN expressions.
  struct HaystackListExpression: Expression {
    public typealias ExpressionValue = T

    /// The list of values to render.
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
  /// Tests whether this expression matches any value in the provided array.
  ///
  /// This method generates an `IN` clause with the values as bound parameters.
  ///
  /// - Parameter array: The array of values to check against.
  /// - Returns: An `InExpression` that evaluates to `true` if the value is found,
  ///            `false` if not found, or `nil` if the expression is NULL.
  public func `in`<T: Bindable>(array: [T]) -> InExpression<T> {
    InExpression(
      needleExpression: self,
      haystackExpression: InExpression.HaystackListExpression(values: array),
      isNegated: false
    )
  }

  /// Tests whether this expression does not match any value in the provided array.
  ///
  /// This method generates a `NOT IN` clause with the values as bound parameters.
  ///
  /// - Parameter array: The array of values to check against.
  /// - Returns: An `InExpression` that evaluates to `true` if the value is not found,
  ///            `false` if found, or `nil` if the expression is NULL.
  public func notIn<T: Bindable>(array: [T]) -> InExpression<T> {
    InExpression(
      needleExpression: self,
      haystackExpression: InExpression.HaystackListExpression(values: array),
      isNegated: true
    )
  }

  /// Tests whether this expression matches any value in the provided variadic list.
  ///
  /// This method generates an `IN` clause with the values as bound parameters.
  ///
  /// - Parameter values: The values to check against.
  /// - Returns: An `InExpression` that evaluates to `true` if the value is found,
  ///            `false` if not found, or `nil` if the expression is NULL.
  public func `in`<T: Bindable>(values: T...) -> InExpression<T> {
    InExpression(
      needleExpression: self,
      haystackExpression: InExpression.HaystackListExpression(values: values),
      isNegated: false
    )
  }

  /// Tests whether this expression does not match any value in the provided variadic list.
  ///
  /// This method generates a `NOT IN` clause with the values as bound parameters.
  ///
  /// - Parameter values: The values to check against.
  /// - Returns: An `InExpression` that evaluates to `true` if the value is not found,
  ///            `false` if found, or `nil` if the expression is NULL.
  public func notIn<T: Bindable>(values: T...) -> InExpression<T> {
    InExpression(
      needleExpression: self,
      haystackExpression: InExpression.HaystackListExpression(values: values),
      isNegated: true
    )
  }

  /// Tests whether this expression matches any value returned by a subquery.
  ///
  /// This method generates an `IN` clause with a subquery expression.
  ///
  /// - Parameter subquery: The subquery expression to check against.
  /// - Returns: An `InExpression` that evaluates to `true` if the value is found in the subquery results,
  ///            `false` if not found, or `nil` if the expression is NULL.
  public func `in`<T: Bindable>(subquery: any Expression<T>) -> InExpression<T> {
    InExpression(needleExpression: self, haystackExpression: subquery, isNegated: false)
  }

  /// Tests whether this expression does not match any value returned by a subquery.
  ///
  /// This method generates a `NOT IN` clause with a subquery expression.
  ///
  /// - Parameter subquery: The subquery expression to check against.
  /// - Returns: An `InExpression` that evaluates to `true` if the value is not found in the subquery results,
  ///            `false` if found, or `nil` if the expression is NULL.
  public func notIn<T: Bindable>(subquery: any Expression<T>) -> InExpression<T> {
    InExpression(needleExpression: self, haystackExpression: subquery, isNegated: true)
  }
}
