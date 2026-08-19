/// SQL `JSON_ERROR_POSITION()` — where a malformed document first breaks.
///
/// The result is 0 when the value is well-formed JSON, the 1-based character position of
/// the first syntax error otherwise, and NULL for NULL input. The companion to
/// ``Expression/jsonValid()``: a validity check finds broken documents, this finds where
/// they are broken.
///
/// ```swift
/// let data = ColumnExpression<String>("data")
/// if #available(iOS 17.0, macOS 14.0, macCatalyst 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) {
///   let firstError = data.jsonErrorPosition()
///   // SQL: JSON_ERROR_POSITION("data")
/// }
/// ```
public struct JSONErrorPosition: Function {
  public typealias ExpressionValue = Int?

  let expression: any Expression

  init(_ expression: any Expression) {
    self.expression = expression
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("JSON_ERROR_POSITION(")
    expression.append(to: &builder)
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// The 1-based position of this document's first JSON syntax error via SQL
  /// `JSON_ERROR_POSITION()` — 0 when the document is well-formed.
  ///
  /// Requires SQLite 3.42+, which ships with the annotated OS versions.
  @available(iOS 17.0, macOS 14.0, macCatalyst 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
  public func jsonErrorPosition() -> JSONErrorPosition {
    JSONErrorPosition(self)
  }
}
