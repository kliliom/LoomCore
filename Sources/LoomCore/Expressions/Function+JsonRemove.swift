import Foundation

/// SQL `JSON_REMOVE()` — a document with the nodes at the given paths removed.
///
/// Paths that select nothing are silently skipped. The result is the modified document —
/// the stored column changes only when you write it back. `ExpressionValue` is optional
/// because a NULL input document yields NULL.
///
/// ```swift
/// let profile = ColumnExpression<String>("profile")
/// let trimmed = profile.jsonRemove("$.legacyField", "$.tags[0]")
/// try await db.exec("UPDATE users SET profile = \(trimmed)")
/// ```
///
/// Generates SQL of the form `JSON_REMOVE("profile", '$.legacyField', '$.tags[0]')`.
public struct JSONRemove<Value>: Function {
  public typealias ExpressionValue = Value?

  let expression: any Expression

  let paths: [JSONPath]

  let representation: JSONRepresentation

  init(expression: any Expression, paths: [JSONPath], representation: JSONRepresentation) {
    precondition(!paths.isEmpty, "JSON_REMOVE requires at least one path")
    self.expression = expression
    self.paths = paths
    self.representation = representation
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("\(representation.sqlName("REMOVE"))(")
    expression.append(to: &builder)
    for path in paths {
      builder.appendLiteral(", \(path.renderedSQL)")
    }
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// This document with the nodes at `paths` removed via SQL `JSON_REMOVE()`.
  ///
  /// ```swift
  /// let profile = ColumnExpression<String>("profile")
  /// let trimmed = profile.jsonRemove("$.legacyField")
  /// // SQL: JSON_REMOVE("profile", '$.legacyField')
  /// ```
  ///
  /// - Parameters:
  ///   - first: First path to remove.
  ///   - rest: Additional paths to remove.
  public func jsonRemove(_ first: JSONPath, _ rest: JSONPath...) -> JSONRemove<String> {
    JSONRemove(expression: self, paths: [first] + rest, representation: .text)
  }

  /// ``jsonRemove(_:_:)`` returning the binary JSONB encoding (`Data`) via `JSONB_REMOVE()`.
  ///
  /// Requires SQLite 3.45+, which ships with the annotated OS versions.
  ///
  /// - Parameters:
  ///   - first: First path to remove.
  ///   - rest: Additional paths to remove.
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  public func jsonbRemove(_ first: JSONPath, _ rest: JSONPath...) -> JSONRemove<Data> {
    JSONRemove(expression: self, paths: [first] + rest, representation: .binary)
  }
}
