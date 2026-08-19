/// One `path, value` pair for ``JSONModify`` (`json_set`, `json_insert`, `json_replace`).
///
/// SQLite treats a bound TEXT argument as a JSON *string*: assigning `{"a":1}` through
/// ``value(_:_:)`` stores the eight-character string, not a nested object. Choose the
/// factory by what the value is:
///
/// - ``value(_:_:)`` binds the argument as-is — right for numbers, strings, and booleans.
/// - ``json(_:_:)`` wraps the bound argument in `JSON(?)` so JSON text — including any
///   ``JSONBindable`` — nests as a real object or array.
///
/// ```swift
/// struct Address: Codable, JSONBindable {
///   let city: String
/// }
///
/// let profile = ColumnExpression<String>("profile")
/// let updated = profile.jsonSet(
///   .value("$.displayName", "Alice"),
///   .json("$.address", Address(city: "Vienna"))
/// )
/// try await db.exec("UPDATE users SET profile = \(updated)")
/// ```
public struct JSONAssignment: Sendable {
  let path: JSONPath

  let value: any Expression

  let wrapsInJSON: Bool

  /// Assigns `value` bound directly — scalars become JSON numbers, strings, or booleans.
  ///
  /// A bound `nil` optional assigns JSON `null`. Swift `Bool` values are rendered as JSON
  /// `true`/`false` — SQLite has no boolean storage class, so binding one would store the
  /// integer 1/0 instead.
  ///
  /// - Parameters:
  ///   - path: Path of the node to assign.
  ///   - value: Expression yielding the value; bound as a parameter.
  public static func value(_ path: JSONPath, _ value: some Expression) -> JSONAssignment {
    JSONAssignment(path: path, value: value, wrapsInJSON: false)
  }

  /// Assigns `value` wrapped in `JSON(?)` — JSON text nests as a sub-document.
  ///
  /// Use this for ``JSONBindable`` values and any string holding a JSON document; the
  /// wrapper parses the text so objects and arrays nest instead of being stored as strings.
  ///
  /// - Parameters:
  ///   - path: Path of the node to assign.
  ///   - value: Expression yielding JSON text; bound as a parameter inside `JSON()`.
  public static func json(_ path: JSONPath, _ value: some Expression) -> JSONAssignment {
    JSONAssignment(path: path, value: value, wrapsInJSON: true)
  }

  func append(to builder: inout SQLBuilder) {
    builder.appendLiteral(", \(path.renderedSQL), ")
    if wrapsInJSON {
      builder.appendLiteral("JSON(")
    }
    builder.appendJSONArgument(value)
    if wrapsInJSON {
      builder.appendLiteral(")")
    }
  }
}
