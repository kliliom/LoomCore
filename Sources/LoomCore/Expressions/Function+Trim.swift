/// An SQL function that removes leading and trailing whitespace from a string.
///
/// This function generates SQL's `TRIM()` function, which removes spaces and other
/// whitespace characters from both ends of a string. The string content itself is
/// not modified. Returns `nil` if the input expression is NULL.
///
/// Example SQL output: `TRIM(column_name)`
public struct Trim: Function {
  public typealias ExpressionValue = String?

  /// The expression to trim.
  let expression: any Expression

  /// Creates a new trim function.
  ///
  /// - Parameter expression: The expression to trim.
  public init(_ expression: any Expression) {
    self.expression = expression
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("TRIM(")
    expression.append(to: &builder)
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// Removes leading and trailing whitespace from this expression.
  ///
  /// - Returns: A `Trim` function that removes whitespace from both ends, or `nil` if the input is NULL.
  public func trim() -> Trim {
    Trim(self)
  }
}
