/// SQL `JSON_ARRAY_LENGTH()` — the element count of a JSON array.
///
/// Returns `0` when the selected node exists but is not an array. The result is `Int?`
/// because a NULL input or a path that selects nothing yields NULL.
///
/// ```swift
/// let profile = ColumnExpression<String>("profile")
/// let tagCount = profile.jsonArrayLength("$.tags")
/// let counts = try await db.query("SELECT \(tagCount) FROM users") { stmt, _ in
///   try Int?.column(of: stmt, at: 0)
/// }
/// ```
///
/// Generates SQL of the form `JSON_ARRAY_LENGTH("profile", '$.tags')`.
public struct JSONArrayLength: Function {
  public typealias ExpressionValue = Int?

  let expression: any Expression

  let path: JSONPath?

  init(_ expression: any Expression, path: JSONPath? = nil) {
    self.expression = expression
    self.path = path
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("JSON_ARRAY_LENGTH(")
    expression.append(to: &builder)
    if let path {
      builder.appendLiteral(", \(path.renderedSQL)")
    }
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// The element count of this expression's JSON array via SQL `JSON_ARRAY_LENGTH()`.
  ///
  /// ```swift
  /// let tags = ColumnExpression<String>("tags")
  /// let count = tags.jsonArrayLength()
  /// // SQL: JSON_ARRAY_LENGTH("tags")
  /// ```
  public func jsonArrayLength() -> JSONArrayLength {
    JSONArrayLength(self)
  }

  /// The element count of the JSON array at `path` via SQL `JSON_ARRAY_LENGTH()`.
  ///
  /// ```swift
  /// let profile = ColumnExpression<String>("profile")
  /// let count = profile.jsonArrayLength("$.tags")
  /// // SQL: JSON_ARRAY_LENGTH("profile", '$.tags')
  /// ```
  ///
  /// - Parameter path: Path of the array to measure.
  public func jsonArrayLength(_ path: JSONPath) -> JSONArrayLength {
    JSONArrayLength(self, path: path)
  }
}
