/// SQL `SUBSTR()` function that extracts a portion of a string.
///
/// Positions are 1-indexed: `start: 1` is the first character. A negative `start` counts from the
/// end of the string. Omitting `length` extracts through the end. Returns `nil` when the input
/// expression evaluates to NULL.
///
/// ```swift
/// let email = ColumnExpression<String>("email", of: "users")
/// let localPart = Substring(email, start: 1, length: 5)
/// // SQL: SUBSTR("users"."email", ?, ?)
/// ```
public struct Substring: Function {
  public typealias ExpressionValue = String?

  let expression: any Expression

  let start: Int

  let length: Int?

  /// Creates a `SUBSTR()` call over `expression`.
  ///
  /// - Parameters:
  ///   - start: 1-indexed starting position. Negative values count from the end of the string.
  ///   - length: Number of characters to extract. When `nil`, extracts through the end.
  public init(_ expression: any Expression, start: Int, length: Int? = nil) {
    self.expression = expression
    self.start = start
    self.length = length
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("SUBSTR(")
    expression.append(to: &builder)
    builder.appendLiteral(", ")
    start.append(to: &builder)
    if let length = length {
      builder.appendLiteral(", ")
      length.append(to: &builder)
    }
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// Extracts a substring of this expression via SQL `SUBSTR()`.
  ///
  /// ```swift
  /// let name = ColumnExpression<String>("name")
  /// let initial = name.substring(start: 1, length: 1)
  /// let suffix = name.substring(start: 2)
  /// ```
  ///
  /// - Parameters:
  ///   - start: 1-indexed starting position. Negative values count from the end.
  ///   - length: Number of characters to extract. When `nil`, extracts through the end.
  public func substring(start: Int, length: Int? = nil) -> Substring {
    Substring(self, start: start, length: length)
  }
}
