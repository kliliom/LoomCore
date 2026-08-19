import Foundation

/// SQL `JSON()` / `JSONB()` — validates a JSON document and converts it to canonical form.
///
/// `JSON()` minifies to canonical JSON text; `JSONB()` produces SQLite's compact binary
/// encoding. Both raise a SQLite error on malformed input, which surfaces as a thrown
/// ``LoomError``. `ExpressionValue` is optional because a NULL input yields NULL.
///
/// ```swift
/// let data = ColumnExpression<String>("data")
/// let canonical = try await db.query("SELECT \(data.json()) FROM events") { stmt, _ in
///   try String?.column(of: stmt, at: 0)
/// }
/// ```
public struct JSONConversion<Value>: Function {
  public typealias ExpressionValue = Value?

  let expression: any Expression

  let representation: JSONRepresentation

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("\(representation.rawValue)(")
    expression.append(to: &builder)
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// Validates and minifies this expression via SQL `JSON()`.
  ///
  /// ```swift
  /// let data = ColumnExpression<String>("data")
  /// let canonical = data.json()
  /// // SQL: JSON("data")
  /// ```
  public func json() -> JSONConversion<String> {
    JSONConversion(expression: self, representation: .text)
  }

  /// Converts this expression to SQLite's binary JSONB encoding via SQL `JSONB()`.
  ///
  /// JSONB is an internal SQLite format: store it and pass it to JSON functions, but do
  /// not parse it outside SQLite. Requires SQLite 3.45+, which ships with the annotated
  /// OS versions.
  ///
  /// ```swift
  /// let data = ColumnExpression<String>("data")
  /// if #available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
  ///   let binary = data.jsonb()
  ///   // SQL: JSONB("data")
  /// }
  /// ```
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  public func jsonb() -> JSONConversion<Data> {
    JSONConversion(expression: self, representation: .binary)
  }
}
