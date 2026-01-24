/// An SQL function that extracts a substring from a string expression.
///
/// This function generates SQL's `SUBSTR()` function, which returns a portion of a string
/// starting at a specified position and optionally with a specified length. Returns `nil`
/// if the input expression is NULL.
///
/// Example SQL output: `SUBSTR(column_name, 1, 5)`
public struct Substring: Function {
  public typealias ExpressionValue = String?

  /// The expression from which to extract the substring.
  let expression: any Expression

  /// The starting position (1-indexed in SQL).
  let start: Int

  /// The optional length of the substring. If `nil`, extracts to the end of the string.
  let length: Int?

  /// Creates a new substring function.
  ///
  /// - Parameters:
  ///   - expression: The expression from which to extract the substring.
  ///   - start: The starting position (1-indexed).
  ///   - length: The optional length of the substring. If `nil`, extracts to the end.
  public init(_ expression: any Expression, start: Int, length: Int? = nil) {
    self.expression = expression
    self.start = start
    self.length = length
  }

  public func append(to builder: inout SQLBuilder) {
    builder.sql.append("SUBSTR(")
    expression.append(to: &builder)
    builder.sql.append(", ")
    start.append(to: &builder)
    if let length = length {
      builder.sql.append(", ")
      length.append(to: &builder)
    }
    builder.sql.append(")")
  }
}

extension Expression {
  /// Extracts a substring from this expression.
  ///
  /// - Parameters:
  ///   - start: The starting position (1-indexed).
  ///   - length: The optional length of the substring. If `nil`, extracts to the end.
  /// - Returns: A `Substring` function that extracts the specified portion of this expression, or `nil` if the input is NULL.
  public func substring(start: Int, length: Int? = nil) -> Substring {
    Substring(self, start: start, length: length)
  }
}
