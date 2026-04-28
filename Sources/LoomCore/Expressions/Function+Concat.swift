/// SQL string concatenation using the `||` operator.
///
/// Joins multiple expressions into a single string in the order provided. Combine
/// columns with literals to build display values directly in SQL:
///
/// ```swift
/// let firstName = ColumnExpression<String>("first_name")
/// let lastName = ColumnExpression<String>("last_name")
/// let fullName = Concat(expressions: [firstName, " ", lastName])
/// // ( "first_name" || ? || "last_name" )
/// ```
public struct Concat: Function {
  public typealias ExpressionValue = String

  let expressions: [any Expression]

  /// Creates a concatenation of the given expressions.
  public init(expressions: [any Expression]) {
    self.expressions = expressions
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("(")
    for (index, expression) in expressions.enumerated() {
      if index > 0 {
        builder.appendLiteral(" || ")
      }
      expression.append(to: &builder)
    }
    builder.appendLiteral(")")
  }
}

/// Concatenates expressions into a single string using SQL's `||` operator.
///
/// Variadic shorthand for ``Concat``:
///
/// ```swift
/// let label = concat(ColumnExpression<String>("city"), ", ", ColumnExpression<String>("country"))
/// // ( "city" || ? || "country" )
/// ```
public func concat(_ expressions: any Expression...) -> Concat {
  Concat(expressions: expressions)
}
