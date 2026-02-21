/// An SQL function that concatenates multiple string expressions into a single string.
///
/// This function uses SQL's concatenation operator (`||`) to join multiple expressions
/// together. All expressions are evaluated and concatenated in the order they are provided.
///
/// Example SQL output: `(column1 || column2 || 'literal')`
public struct Concat: Function {
  public typealias ExpressionValue = String

  /// The expressions to concatenate.
  let expressions: [any Expression]

  /// Creates a new concatenation function.
  ///
  /// - Parameter expressions: An array of expressions to concatenate together.
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

/// Concatenates multiple expressions into a single string.
///
/// This is a convenience function that creates a `Concat` function from a variadic
/// list of expressions.
///
/// - Parameter expressions: The expressions to concatenate together.
/// - Returns: A `Concat` function that joins all expressions.
public func concat(_ expressions: any Expression...) -> Concat {
  Concat(expressions: expressions)
}
