// MARK: - JSON Access Operators

/// JSON access via SQLite's `->` and `->>` operators.
///
/// Build instances through ``Expression/jsonFragment(_:)`` (`->`, sub-document as JSON text)
/// and ``Expression/jsonValue(_:as:)`` (`->>`, node as a plain SQL value); like the rest of
/// the JSON surface, the type has no public initializer. Swift reserves the `->` token, so
/// the operators are exposed as methods.
///
/// ```swift
/// let profile = ColumnExpression<String>("profile")
/// let city = profile.jsonValue("$.address.city", as: String.self)
/// let admins = try await db.query("SELECT id FROM users WHERE \(city == "Vienna")") { stmt, _ in
///   try Int64.column(of: stmt, at: 0)
/// }
/// ```
///
/// Both operators require SQLite 3.38+, which every OS version LoomCore supports ships.
public struct JSONAccessExpression<Operand: Expression, Value>: Expression {
  public typealias ExpressionValue = Value?

  enum Operator: String, Sendable {
    /// `->` — the selected node as JSON text (or NULL).
    case arrow = "->"
    /// `->>` — the selected node as a plain SQL value: INTEGER, REAL, TEXT, or NULL.
    case doubleArrow = "->>"
  }

  let operand: Operand

  let op: Operator

  let path: JSONPath

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("(")
    operand.append(to: &builder)
    builder.appendLiteral(op.rawValue)
    builder.appendLiteral(path.renderedSQL)
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// Selects the sub-document at `path` via SQLite's `->` operator.
  ///
  /// The result is always JSON text (or NULL): a string node keeps its quotes (`"Alice"`),
  /// and objects/arrays stay JSON. Because the result is itself a JSON document, calls
  /// chain — and the result can be stored back into a JSON column.
  ///
  /// ```swift
  /// let profile = ColumnExpression<String>("profile")
  /// let address = profile.jsonFragment("$.address")
  /// // SQL: ("profile"->'$.address')
  /// let city = address.jsonValue("$.city", as: String.self)
  /// ```
  ///
  /// For unwrapped scalar values, use ``jsonValue(_:as:)`` instead.
  ///
  /// - Parameter path: Path of the sub-document to select.
  public func jsonFragment(_ path: JSONPath) -> JSONAccessExpression<Self, String> {
    JSONAccessExpression(operand: self, op: .arrow, path: path)
  }

  /// Selects the value at `path` via SQLite's `->>` operator, decoded as `V?`.
  ///
  /// Unlike ``jsonFragment(_:)``, the result is a plain SQL value: a string node loses its
  /// JSON quotes, numbers come back as INTEGER/REAL. State the node's Swift type with `as:`
  /// — a mismatch between the node's storage class and `V` throws ``LoomError`` with code
  /// ``LoomCoreErrorCode/typeMappingFailed`` when the row is read.
  ///
  /// ```swift
  /// let profile = ColumnExpression<String>("profile")
  /// let age = profile.jsonValue("$.age", as: Int.self)
  /// // SQL: ("profile"->>'$.age')
  /// ```
  ///
  /// - Parameters:
  ///   - path: Path of the node to select.
  ///   - type: Swift type the node decodes to.
  public func jsonValue<V: Bindable>(_ path: JSONPath, as type: V.Type) -> JSONAccessExpression<Self, V> {
    JSONAccessExpression(operand: self, op: .doubleArrow, path: path)
  }
}
