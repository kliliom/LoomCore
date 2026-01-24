/// An SQL function that converts a string to lowercase.
///
/// This function generates SQL's `LOWER()` function, which converts all uppercase
/// characters in a string to lowercase. Non-alphabetic characters are not affected.
/// Returns `nil` if the input expression is NULL.
///
/// Example SQL output: `LOWER(column_name)`
public struct Lower: Function {
  public typealias ExpressionValue = String?

  /// The expression to convert to lowercase.
  let expression: any Expression

  /// Creates a new lowercase function.
  ///
  /// - Parameter expression: The expression to convert to lowercase.
  public init(_ expression: any Expression) {
    self.expression = expression
  }

  public func append(to builder: inout SQLBuilder) {
    builder.sql.append("LOWER(")
    expression.append(to: &builder)
    builder.sql.append(")")
  }
}

extension Expression {
  /// Converts this expression to lowercase.
  ///
  /// - Returns: A `Lower` function that converts the string to lowercase, or `nil` if the input is NULL.
  public func lower() -> Lower {
    Lower(self)
  }
}
