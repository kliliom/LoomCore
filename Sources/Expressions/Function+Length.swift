/// An SQL function that returns the length of a string or blob.
///
/// This function generates SQL's `LENGTH()` function, which returns the number of
/// characters in a string or the number of bytes in a blob. The result is optional
/// because the input expression may be NULL.
///
/// Example SQL output: `LENGTH(column_name)`
public struct Length: Function {
  public typealias ExpressionValue = Int?

  /// The expression to get the length of.
  let expression: any Expression

  /// Creates a new length function.
  ///
  /// - Parameter expression: The expression to get the length of.
  public init(_ expression: any Expression) {
    self.expression = expression
  }

  public func append(to builder: inout SQLBuilder) {
    builder.sql.append("LENGTH(")
    expression.append(to: &builder)
    builder.sql.append(")")
  }
}

extension Expression {
  /// Returns the length of this expression.
  ///
  /// - Returns: A `Length` function that computes the number of characters or bytes.
  public func length() -> Length {
    Length(self)
  }
}
