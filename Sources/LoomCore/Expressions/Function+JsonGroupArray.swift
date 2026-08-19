import Foundation

/// SQL `JSON_GROUP_ARRAY()` aggregate — a JSON array collecting one value per grouped row.
///
/// `ExpressionValue` is non-optional because an empty group yields `'[]'`. A NULL input
/// value becomes a JSON `null` element.
///
/// A TEXT value becomes a JSON *string* element; wrap the expression in
/// ``Expression/json()`` to nest documents instead.
///
/// ```swift
/// // SELECT author_id, JSON_GROUP_ARRAY("title") FROM books GROUP BY author_id
/// let title = ColumnExpression<String>("title")
/// let titles = title.jsonGroupArray()
/// ```
public struct JSONGroupArray<Value>: Function {
  public typealias ExpressionValue = Value

  let expression: any Expression

  let representation: JSONRepresentation

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("\(representation.sqlName("GROUP_ARRAY"))(")
    expression.append(to: &builder)
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// Aggregates this expression's grouped values into a JSON array via
  /// SQL `JSON_GROUP_ARRAY()`.
  ///
  /// ```swift
  /// let title = ColumnExpression<String>("title")
  /// let titles = title.jsonGroupArray()
  /// // SQL: JSON_GROUP_ARRAY("title")
  /// ```
  public func jsonGroupArray() -> JSONGroupArray<String> {
    JSONGroupArray(expression: self, representation: .text)
  }

  /// ``jsonGroupArray()`` returning the binary JSONB encoding (`Data`) via
  /// `JSONB_GROUP_ARRAY()`.
  ///
  /// Requires SQLite 3.45+, which ships with the annotated OS versions.
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  public func jsonbGroupArray() -> JSONGroupArray<Data> {
    JSONGroupArray(expression: self, representation: .binary)
  }
}
