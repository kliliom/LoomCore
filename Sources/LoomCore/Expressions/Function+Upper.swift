/// An SQL function that converts a string to uppercase.
///
/// This function generates SQL's `UPPER()` function, which converts all lowercase
/// characters in a string to uppercase. Non-alphabetic characters are not affected.
/// Returns `nil` if the input expression is NULL.
///
/// Example SQL output: `UPPER(column_name)`
public struct Upper: Function {
  public typealias ExpressionValue = String?

  /// The expression to convert to uppercase.
  let expression: any Expression

  /// Creates a new uppercase function.
  ///
  /// - Parameter expression: The expression to convert to uppercase.
  public init(_ expression: any Expression) {
    self.expression = expression
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("UPPER(")
    expression.append(to: &builder)
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// Converts this expression to uppercase.
  ///
  /// - Returns: An `Upper` function that converts the string to uppercase, or `nil` if the input is NULL.
  public func upper() -> Upper {
    Upper(self)
  }
}
