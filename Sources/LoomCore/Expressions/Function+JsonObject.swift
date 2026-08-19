import Foundation

/// SQL `JSON_OBJECT()` — a JSON object built from label/value pairs.
///
/// Build instances through the ``jsonObject(_:)`` free function. `ExpressionValue` is
/// non-optional: with no arguments the result is `'{}'`, and a NULL value becomes a JSON
/// `null` member rather than making the whole result NULL.
///
/// Labels are bound as parameters — they are data, not identifiers. A TEXT value becomes a
/// JSON *string* member; wrap an expression in ``Expression/json()`` to nest a JSON
/// document instead. Swift `Bool` values are rendered as JSON `true`/`false` — SQLite has
/// no boolean storage class, so binding one would store the integer 1/0 instead.
///
/// ```swift
/// let name = ColumnExpression<String>("name")
/// let tags = ColumnExpression<String>("tags")
/// let docs = try await db.query(
///   "SELECT \(jsonObject(("name", name), ("tags", tags.json()))) FROM users"
/// ) { stmt, _ in
///   try String.column(of: stmt, at: 0)
/// }
/// ```
public struct JSONObject<Value>: Function {
  public typealias ExpressionValue = Value

  let entries: [(label: String, value: any Expression)]

  let representation: JSONRepresentation

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("\(representation.sqlName("OBJECT"))(")
    for (index, entry) in entries.enumerated() {
      if index > 0 {
        builder.appendLiteral(", ")
      }
      entry.label.append(to: &builder)
      builder.appendLiteral(", ")
      builder.appendJSONArgument(entry.value)
    }
    builder.appendLiteral(")")
  }
}

/// Builds a JSON object from label/value pairs via SQL `JSON_OBJECT()`.
///
/// ```swift
/// let name = ColumnExpression<String>("name")
/// let doc = jsonObject(("name", name), ("age", 30))
/// // SQL: JSON_OBJECT(?, "name", ?, ?)
/// ```
///
/// - Parameter entries: Label/value pairs; an empty list yields `'{}'`.
public func jsonObject(_ entries: (String, any Expression)...) -> JSONObject<String> {
  JSONObject(entries: entries.map { (label: $0.0, value: $0.1) }, representation: .text)
}

/// ``jsonObject(_:)`` returning the binary JSONB encoding (`Data`) via `JSONB_OBJECT()`.
///
/// Requires SQLite 3.45+, which ships with the annotated OS versions.
///
/// - Parameter entries: Label/value pairs; an empty list yields the JSONB encoding of `{}`.
@available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
public func jsonbObject(_ entries: (String, any Expression)...) -> JSONObject<Data> {
  JSONObject(entries: entries.map { (label: $0.0, value: $0.1) }, representation: .binary)
}
