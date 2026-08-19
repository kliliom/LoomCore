import Foundation

/// SQL `JSON_SET()` / `JSON_INSERT()` / `JSON_REPLACE()` — a document with edits applied.
///
/// The three functions share one argument shape and differ only in when an edit applies:
/// `SET` overwrites or creates, `INSERT` only creates, `REPLACE` only overwrites. Build
/// instances through ``Expression/jsonSet(_:_:)``, ``Expression/jsonInsert(_:_:)``, and
/// ``Expression/jsonReplace(_:_:)``. The result is the modified document; the stored column
/// changes only when you write it back in an `UPDATE`.
///
/// ```swift
/// let profile = ColumnExpression<String>("profile")
/// let renamed = profile.jsonSet(.value("$.displayName", "Alice"))
/// try await db.exec("UPDATE users SET profile = \(renamed)")
/// ```
///
/// `ExpressionValue` is optional because a NULL input document yields NULL. See
/// ``JSONAssignment`` for the JSON-nesting subtlety of assigned values.
public struct JSONModify<Value>: Function {
  public typealias ExpressionValue = Value?

  enum Kind: String, Sendable {
    case set = "SET"
    case insert = "INSERT"
    case replace = "REPLACE"
  }

  let expression: any Expression

  let representation: JSONRepresentation

  let kind: Kind

  let assignments: [JSONAssignment]

  init(expression: any Expression, representation: JSONRepresentation, kind: Kind, assignments: [JSONAssignment]) {
    precondition(!assignments.isEmpty, "JSON modification requires at least one assignment")
    self.expression = expression
    self.representation = representation
    self.kind = kind
    self.assignments = assignments
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("\(representation.sqlName(kind.rawValue))(")
    expression.append(to: &builder)
    for assignment in assignments {
      assignment.append(to: &builder)
    }
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// This document with `assignments` applied via SQL `JSON_SET()` — overwrites existing
  /// nodes and creates missing ones.
  ///
  /// ```swift
  /// let profile = ColumnExpression<String>("profile")
  /// let updated = profile.jsonSet(.value("$.age", 30), .value("$.verified", true))
  /// // SQL: JSON_SET("profile", '$.age', ?, '$.verified', ?)
  /// ```
  ///
  /// - Parameters:
  ///   - first: First path/value pair.
  ///   - rest: Additional path/value pairs.
  public func jsonSet(_ first: JSONAssignment, _ rest: JSONAssignment...) -> JSONModify<String> {
    JSONModify(expression: self, representation: .text, kind: .set, assignments: [first] + rest)
  }

  /// This document with `assignments` applied via SQL `JSON_INSERT()` — creates missing
  /// nodes and leaves existing ones untouched.
  ///
  /// ```swift
  /// let profile = ColumnExpression<String>("profile")
  /// let defaulted = profile.jsonInsert(.value("$.theme", "light"))
  /// // SQL: JSON_INSERT("profile", '$.theme', ?)
  /// ```
  ///
  /// - Parameters:
  ///   - first: First path/value pair.
  ///   - rest: Additional path/value pairs.
  public func jsonInsert(_ first: JSONAssignment, _ rest: JSONAssignment...) -> JSONModify<String> {
    JSONModify(expression: self, representation: .text, kind: .insert, assignments: [first] + rest)
  }

  /// This document with `assignments` applied via SQL `JSON_REPLACE()` — overwrites
  /// existing nodes and skips missing ones.
  ///
  /// ```swift
  /// let profile = ColumnExpression<String>("profile")
  /// let corrected = profile.jsonReplace(.value("$.age", 31))
  /// // SQL: JSON_REPLACE("profile", '$.age', ?)
  /// ```
  ///
  /// - Parameters:
  ///   - first: First path/value pair.
  ///   - rest: Additional path/value pairs.
  public func jsonReplace(_ first: JSONAssignment, _ rest: JSONAssignment...) -> JSONModify<String> {
    JSONModify(expression: self, representation: .text, kind: .replace, assignments: [first] + rest)
  }

  /// ``jsonSet(_:_:)`` returning the binary JSONB encoding (`Data`) via `JSONB_SET()`.
  ///
  /// Requires SQLite 3.45+, which ships with the annotated OS versions.
  ///
  /// - Parameters:
  ///   - first: First path/value pair.
  ///   - rest: Additional path/value pairs.
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  public func jsonbSet(_ first: JSONAssignment, _ rest: JSONAssignment...) -> JSONModify<Data> {
    JSONModify(expression: self, representation: .binary, kind: .set, assignments: [first] + rest)
  }

  /// ``jsonInsert(_:_:)`` returning the binary JSONB encoding (`Data`) via `JSONB_INSERT()`.
  ///
  /// Requires SQLite 3.45+, which ships with the annotated OS versions.
  ///
  /// - Parameters:
  ///   - first: First path/value pair.
  ///   - rest: Additional path/value pairs.
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  public func jsonbInsert(_ first: JSONAssignment, _ rest: JSONAssignment...) -> JSONModify<Data> {
    JSONModify(expression: self, representation: .binary, kind: .insert, assignments: [first] + rest)
  }

  /// ``jsonReplace(_:_:)`` returning the binary JSONB encoding (`Data`) via `JSONB_REPLACE()`.
  ///
  /// Requires SQLite 3.45+, which ships with the annotated OS versions.
  ///
  /// - Parameters:
  ///   - first: First path/value pair.
  ///   - rest: Additional path/value pairs.
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  public func jsonbReplace(_ first: JSONAssignment, _ rest: JSONAssignment...) -> JSONModify<Data> {
    JSONModify(expression: self, representation: .binary, kind: .replace, assignments: [first] + rest)
  }
}
