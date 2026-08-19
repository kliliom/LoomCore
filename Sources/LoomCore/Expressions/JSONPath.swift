/// A SQLite JSON path such as `$.user.name`, `$[0]`, or `$."key with spaces"`.
///
/// Paths render into SQL as single-quoted literals, not bound parameters: SQLite matches an
/// expression index on `json_extract("col", '$.a')` only when the path is a literal token,
/// so binding it as `?` would silently disable indexed JSON lookups. (Same reasoning as the
/// ESCAPE operand in ``LikeExpression``.)
///
/// ```swift
/// let profile = ColumnExpression<String>("profile")
/// let city = profile.jsonValue("$.address.city", as: String.self)
/// // SQL: ("profile"->>'$.address.city')
/// ```
///
/// Because a path is inlined, treat it like a column name — a trusted identifier from your
/// own code, not user input. Single quotes are doubled so a path can never break out of its
/// literal, but a hostile path can still select a different node than intended — and
/// through the mutating functions it can affect far more than one member: `"$"` passed to
/// `jsonSet` replaces the whole document, and to `jsonRemove` deletes it (yielding NULL).
///
/// One consequence of literal rendering: statements differing only in their JSON paths are
/// distinct entries in the prepared-statement cache. That is the point (index matching), but
/// worth knowing if you generate many dynamic paths.
///
/// ## Validation
///
/// Paths are validated at construction. Empty strings, strings containing a NUL byte (`\0`),
/// and strings not starting with `$` trigger a precondition failure.
public struct JSONPath: Sendable, Hashable, ExpressibleByStringLiteral, CustomStringConvertible {
  /// The path as supplied at construction, e.g. `$.a[0]`.
  public let path: String

  // Single-quoted, quote-doubled rendering, computed once here: a path is built once but
  // appended on every execution of every query it appears in (mirrors ColumnExpression).
  let renderedSQL: String

  /// Creates a JSON path.
  ///
  /// - Parameter path: The path text. Must be non-empty, free of NUL bytes, and start
  ///   with `$` (SQLite's root marker).
  public init(_ path: String) {
    precondition(!path.isEmpty, "JSON path cannot be empty")
    precondition(!path.contains("\0"), "JSON path cannot contain a NUL byte")
    precondition(path.hasPrefix("$"), "JSON path must start with '$'")
    self.path = path
    self.renderedSQL = "'\(path.doublingOccurrences(of: "'"))'"
  }

  /// Creates a JSON path from a string literal, so call sites can pass `"$.name"` directly.
  public init(stringLiteral value: String) {
    self.init(value)
  }

  public var description: String { path }
}
