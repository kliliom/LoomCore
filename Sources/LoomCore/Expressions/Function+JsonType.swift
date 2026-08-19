/// SQL `JSON_TYPE()` — the type name of a JSON value or of the node at a path.
///
/// The result is one of `'null'`, `'true'`, `'false'`, `'integer'`, `'real'`, `'text'`,
/// `'array'`, or `'object'`. It is `String?` because the result is NULL when the input is
/// NULL or the path selects nothing.
///
/// ```swift
/// let profile = ColumnExpression<String>("profile")
/// let kinds = try await db.query("SELECT \(profile.jsonType("$.tags")) FROM users") { stmt, _ in
///   try String?.column(of: stmt, at: 0)
/// }
/// ```
///
/// Generates SQL of the form `JSON_TYPE("profile", '$.tags')`.
public struct JSONType: Function {
  public typealias ExpressionValue = String?

  let expression: any Expression

  let path: JSONPath?

  init(_ expression: any Expression, path: JSONPath? = nil) {
    self.expression = expression
    self.path = path
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("JSON_TYPE(")
    expression.append(to: &builder)
    if let path {
      builder.appendLiteral(", \(path.renderedSQL)")
    }
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// The JSON type name of this expression's document via SQL `JSON_TYPE()`.
  ///
  /// ```swift
  /// let profile = ColumnExpression<String>("profile")
  /// let wholeDocument = profile.jsonType()
  /// // SQL: JSON_TYPE("profile")
  /// ```
  public func jsonType() -> JSONType {
    JSONType(self)
  }

  /// The JSON type name of the node at `path` via SQL `JSON_TYPE()`.
  ///
  /// ```swift
  /// let profile = ColumnExpression<String>("profile")
  /// let tagsType = profile.jsonType("$.tags")
  /// // SQL: JSON_TYPE("profile", '$.tags')
  /// ```
  ///
  /// - Parameter path: Path of the node to inspect.
  public func jsonType(_ path: JSONPath) -> JSONType {
    JSONType(self, path: path)
  }
}
