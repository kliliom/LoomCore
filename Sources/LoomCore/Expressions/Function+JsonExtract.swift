import Foundation

/// SQL `JSON_EXTRACT()` — the value at a JSON path, decoded as `Value?`.
///
/// The result is optional because a NULL document, a NULL argument, or a path that selects
/// nothing all yield NULL. The caller states the expected Swift type because `json_extract`
/// returns whatever storage class the selected node has — `INTEGER` for `$.age`, `TEXT` for
/// `$.name`, JSON `TEXT` for objects and arrays — and column reads are strictly checked
/// against the storage class.
///
/// ```swift
/// let profile = ColumnExpression<String>("profile")
/// let age = profile.jsonExtract("$.age", as: Int.self)
/// let ages = try await db.query("SELECT \(age) FROM users") { stmt, _ in
///   try Int?.column(of: stmt, at: 0)
/// }
/// ```
///
/// Generates SQL of the form `JSON_EXTRACT("profile", '$.age')`. The path renders as a
/// literal, not a bound parameter — see ``JSONPath`` for why.
public struct JSONExtract<Value>: Function {
  public typealias ExpressionValue = Value?

  let expression: any Expression

  // Single path only: the multi-path form of json_extract changes the result type to a
  // JSON array, which would silently invalidate `Value`.
  let path: JSONPath

  let representation: JSONRepresentation

  init(expression: any Expression, path: JSONPath, representation: JSONRepresentation) {
    self.expression = expression
    self.path = path
    self.representation = representation
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("\(representation.sqlName("EXTRACT"))(")
    expression.append(to: &builder)
    builder.appendLiteral(", \(path.renderedSQL)")
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// Extracts the value at `path` via SQL `JSON_EXTRACT()`, decoded as `V?`.
  ///
  /// State the Swift type of the node with `as:` — extraction is strictly typed, and a
  /// mismatch between the node's storage class and `V` throws
  /// ``LoomError`` with code ``LoomCoreErrorCode/typeMappingFailed`` when the row is read.
  ///
  /// ```swift
  /// let profile = ColumnExpression<String>("profile")
  /// let name = profile.jsonExtract("$.displayName", as: String.self)
  /// // SQL: JSON_EXTRACT("profile", '$.displayName')
  /// ```
  ///
  /// Objects and arrays extract as their JSON text — use `as: String.self` for those.
  ///
  /// - Parameters:
  ///   - path: Path of the node to extract.
  ///   - type: Swift type the node decodes to.
  public func jsonExtract<V: Bindable>(_ path: JSONPath, as type: V.Type) -> JSONExtract<V> {
    JSONExtract(expression: self, path: path, representation: .text)
  }

  /// Extracts the value at `path` via SQL `JSONB_EXTRACT()`, decoded as `V?`.
  ///
  /// Same as ``jsonExtract(_:as:)`` except that an object or array node extracts as its
  /// binary JSONB encoding (`Data`) rather than JSON text. Scalar nodes decode identically.
  ///
  /// Requires SQLite 3.45+, which ships with the annotated OS versions.
  ///
  /// - Parameters:
  ///   - path: Path of the node to extract.
  ///   - type: Swift type the node decodes to.
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  public func jsonbExtract<V: Bindable>(_ path: JSONPath, as type: V.Type) -> JSONExtract<V> {
    JSONExtract(expression: self, path: path, representation: .binary)
  }
}
