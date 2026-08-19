import Foundation

/// SQL `JSON_PATCH()` — an RFC 7396 MergePatch of one document onto another.
///
/// Keys in `patch` overwrite matching keys in the target, new keys are added, and a JSON
/// `null` in the patch removes the key. Unlike ``JSONAssignment``, no `JSON()` wrapping is
/// needed: both arguments of `json_patch` are parsed as JSON, so a bound ``JSONBindable``
/// value — which binds its JSON text — merges as a document, exactly as intended.
///
/// ```swift
/// struct ProfilePatch: Codable, JSONBindable {
///   let displayName: String
/// }
///
/// let profile = ColumnExpression<String>("profile")
/// let merged = profile.jsonPatch(ProfilePatch(displayName: "Alice"))
/// try await db.exec("UPDATE users SET profile = \(merged)")
/// ```
///
/// `ExpressionValue` is optional because a NULL target or patch yields NULL.
public struct JSONPatch<Value>: Function {
  public typealias ExpressionValue = Value?

  let expression: any Expression

  let patch: any Expression

  let representation: JSONRepresentation

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("\(representation.sqlName("PATCH"))(")
    expression.append(to: &builder)
    builder.appendLiteral(", ")
    patch.append(to: &builder)
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// Merges `patch` onto this document via SQL `JSON_PATCH()` (RFC 7396 MergePatch).
  ///
  /// ```swift
  /// let profile = ColumnExpression<String>("profile")
  /// let merged = profile.jsonPatch(#"{"displayName":"Alice","legacyField":null}"#)
  /// // SQL: JSON_PATCH("profile", ?)
  /// ```
  ///
  /// - Parameter patch: Expression yielding the patch document; bound as a parameter.
  public func jsonPatch(_ patch: some Expression) -> JSONPatch<String> {
    JSONPatch(expression: self, patch: patch, representation: .text)
  }

  /// ``jsonPatch(_:)`` returning the binary JSONB encoding (`Data`) via `JSONB_PATCH()`.
  ///
  /// Requires SQLite 3.45+, which ships with the annotated OS versions.
  ///
  /// - Parameter patch: Expression yielding the patch document; bound as a parameter.
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  public func jsonbPatch(_ patch: some Expression) -> JSONPatch<Data> {
    JSONPatch(expression: self, patch: patch, representation: .binary)
  }
}
