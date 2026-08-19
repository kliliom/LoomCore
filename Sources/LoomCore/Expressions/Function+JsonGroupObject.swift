import Foundation

/// SQL `JSON_GROUP_OBJECT()` aggregate — a JSON object collecting one member per grouped row.
///
/// Build instances through the ``jsonGroupObject(name:value:)`` free function.
/// `ExpressionValue` is non-optional because an empty group yields `'{}'`. A NULL value
/// becomes a JSON `null` member.
///
/// ```swift
/// // SELECT JSON_GROUP_OBJECT("key", "value") FROM settings
/// let key = ColumnExpression<String>("key")
/// let value = ColumnExpression<String>("value")
/// let settings = jsonGroupObject(name: key, value: value)
/// ```
public struct JSONGroupObject<Value>: Function {
  public typealias ExpressionValue = Value

  let name: any Expression

  let value: any Expression

  let representation: JSONRepresentation

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("\(representation.sqlName("GROUP_OBJECT"))(")
    name.append(to: &builder)
    builder.appendLiteral(", ")
    value.append(to: &builder)
    builder.appendLiteral(")")
  }
}

/// Aggregates grouped rows into a JSON object via SQL `JSON_GROUP_OBJECT()`.
///
/// ```swift
/// let key = ColumnExpression<String>("key")
/// let value = ColumnExpression<String>("value")
/// let settings = jsonGroupObject(name: key, value: value)
/// // SQL: JSON_GROUP_OBJECT("key", "value")
/// ```
///
/// - Parameters:
///   - name: Expression yielding each member's key.
///   - value: Expression yielding each member's value.
public func jsonGroupObject(name: any Expression, value: any Expression) -> JSONGroupObject<String> {
  JSONGroupObject(name: name, value: value, representation: .text)
}

/// ``jsonGroupObject(name:value:)`` returning the binary JSONB encoding (`Data`) via
/// `JSONB_GROUP_OBJECT()`.
///
/// Requires SQLite 3.45+, which ships with the annotated OS versions.
///
/// - Parameters:
///   - name: Expression yielding each member's key.
///   - value: Expression yielding each member's value.
@available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
public func jsonbGroupObject(name: any Expression, value: any Expression) -> JSONGroupObject<Data> {
  JSONGroupObject(name: name, value: value, representation: .binary)
}
