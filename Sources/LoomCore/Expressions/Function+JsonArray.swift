import Foundation

/// SQL `JSON_ARRAY()` — a JSON array built from the argument values.
///
/// Build instances through the ``jsonArray(_:)`` free function. `ExpressionValue` is
/// non-optional: with no arguments the result is `'[]'`, and a NULL argument becomes a JSON
/// `null` element rather than making the whole result NULL.
///
/// A TEXT argument becomes a JSON *string* element; wrap an expression in
/// ``Expression/json()`` to nest a JSON document instead. Swift `Bool` values are rendered
/// as JSON `true`/`false` — SQLite has no boolean storage class, so binding one would
/// store the integer 1/0 instead.
///
/// ```swift
/// let name = ColumnExpression<String>("name")
/// let age = ColumnExpression<Int>("age")
/// let pairs = try await db.query("SELECT \(jsonArray(name, age)) FROM users") { stmt, _ in
///   try String.column(of: stmt, at: 0)
/// }
/// ```
public struct JSONArray<Value>: Function {
  public typealias ExpressionValue = Value

  let expressions: [any Expression]

  let representation: JSONRepresentation

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("\(representation.sqlName("ARRAY"))(")
    for (index, expression) in expressions.enumerated() {
      if index > 0 {
        builder.appendLiteral(", ")
      }
      builder.appendJSONArgument(expression)
    }
    builder.appendLiteral(")")
  }
}

/// Builds a JSON array from `values` via SQL `JSON_ARRAY()`.
///
/// ```swift
/// let name = ColumnExpression<String>("name")
/// let entry = jsonArray(name, 1, true)
/// // SQL: JSON_ARRAY("name", ?, ?)
/// ```
///
/// - Parameter values: Element expressions; an empty list yields `'[]'`.
public func jsonArray(_ values: any Expression...) -> JSONArray<String> {
  JSONArray(expressions: values, representation: .text)
}

/// ``jsonArray(_:)`` returning the binary JSONB encoding (`Data`) via `JSONB_ARRAY()`.
///
/// Requires SQLite 3.45+, which ships with the annotated OS versions.
///
/// - Parameter values: Element expressions; an empty list yields the JSONB encoding of `[]`.
@available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
public func jsonbArray(_ values: any Expression...) -> JSONArray<Data> {
  JSONArray(expressions: values, representation: .binary)
}
