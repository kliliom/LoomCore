/// A typed FTS5 match query, built from phrases and combinators and rendered to FTS5
/// query syntax.
///
/// FTS5's query language has its own grammar — bare tokens, quoted phrases, `AND`/`OR`/`NOT`,
/// `NEAR()`, column filters, `*` prefixes — and malformed input only fails when SQLite
/// executes the statement. `FTS5Query` builds queries that are correct by construction:
/// phrase text is always quoted (with embedded `"` doubled), so user-supplied text can never
/// be misread as operators or column filters.
///
/// ```swift
/// let query = FTS5Query.phrase("swift concurrency").and(.prefix("data"))
/// // Renders: ("swift concurrency" AND "data"*)
///
/// let articles = FTS5Table("articles")
/// let hits = try await db.query(
///   "SELECT title FROM articles WHERE \(articles.match(query))"
/// ) { stmt, _ in
///   try String.column(of: stmt, at: 0)
/// }
/// ```
///
/// The rendered query is bound as a parameter, exactly like a raw string passed to
/// ``FTS5Table/match(_:)->MatchExpression<R>``; the two entry points are interchangeable.
///
/// Phrase text is treated as data and never validated — quoting neutralizes every FTS5
/// metacharacter. Column names in ``column(_:_:)`` and ``columns(_:_:)`` are trusted
/// identifiers and are precondition-validated like column names elsewhere in the DSL.
///
/// ## See Also
/// - ``FTS5Table``
/// - ``MatchExpression``
public struct FTS5Query: Sendable, Hashable, CustomStringConvertible {
  /// The rendered FTS5 query syntax, e.g. `("swift" AND "data"*)`.
  public let queryText: String

  init(rendered: String) {
    self.queryText = rendered
  }

  public var description: String { queryText }

  // MARK: - Phrases

  /// A quoted phrase: the tokens of `text` must appear adjacently, in order.
  ///
  /// Multi-word text is a single FTS5 phrase — `phrase("swift data")` matches only rows
  /// where "swift" is immediately followed by "data", unlike the raw query `swift data`,
  /// which matches both tokens anywhere in the row.
  ///
  /// Empty text renders as `""`, which matches no rows.
  ///
  /// - Parameters:
  ///   - text: Phrase text. Treated as data; never interpreted as FTS5 syntax.
  ///   - fromStart: When `true`, prepends `^` so the phrase matches only at the start
  ///     of a column.
  public static func phrase(_ text: String, fromStart: Bool = false) -> FTS5Query {
    FTS5Query(rendered: (fromStart ? "^" : "") + quote(text))
  }

  /// A quoted prefix phrase: like ``phrase(_:fromStart:)``, but the last token matches
  /// by prefix.
  ///
  /// `prefix("swi")` renders `"swi"*` and matches "swift", "swim", and so on. With
  /// multi-word text the `*` applies to the final token only: `prefix("swift dat")`
  /// matches "swift database" but not "database swift".
  ///
  /// - Parameters:
  ///   - text: Phrase text. Treated as data; never interpreted as FTS5 syntax.
  ///   - fromStart: When `true`, prepends `^` so the phrase matches only at the start
  ///     of a column.
  public static func prefix(_ text: String, fromStart: Bool = false) -> FTS5Query {
    FTS5Query(rendered: (fromStart ? "^" : "") + quote(text) + "*")
  }

  /// A `NEAR()` group: all phrases must appear within `distance` tokens of each other.
  ///
  /// ```swift
  /// let query = FTS5Query.near(["swift", "database"], distance: 5)
  /// // Renders: NEAR("swift" "database", 5)
  /// ```
  ///
  /// Takes phrase strings rather than sub-queries because FTS5's grammar only permits
  /// phrases inside `NEAR()`.
  ///
  /// - Parameters:
  ///   - phrases: Phrase texts, quoted like ``phrase(_:fromStart:)``. Must be non-empty.
  ///   - distance: Maximum number of tokens between the first and last phrase. Must be
  ///     non-negative. FTS5's default is 10.
  public static func near(_ phrases: [String], distance: Int = 10) -> FTS5Query {
    precondition(!phrases.isEmpty, "NEAR requires at least one phrase")
    precondition(distance >= 0, "NEAR distance cannot be negative")
    let rendered = phrases.map(quote).joined(separator: " ")
    return FTS5Query(rendered: "NEAR(\(rendered), \(distance))")
  }

  // MARK: - Column Filters

  /// Restricts `query` to a single column.
  ///
  /// ```swift
  /// let query = FTS5Query.column("title", .phrase("swift"))
  /// // Renders: "title" : ("swift")
  /// ```
  ///
  /// - Parameters:
  ///   - column: Column name — a trusted identifier. Must be non-empty and free of
  ///     NUL bytes.
  ///   - query: The query to restrict.
  public static func column(_ column: String, _ query: FTS5Query) -> FTS5Query {
    FTS5Table.validate(column, role: "Column")
    return FTS5Query(rendered: "\(FTS5Table.escape(column)) : (\(query.queryText))")
  }

  /// Restricts `query` to a set of columns.
  ///
  /// ```swift
  /// let query = FTS5Query.columns(["title", "summary"], .phrase("swift"))
  /// // Renders: {"title" "summary"} : ("swift")
  /// ```
  ///
  /// - Parameters:
  ///   - columns: Column names — trusted identifiers. Must be non-empty; each name must
  ///     be non-empty and free of NUL bytes.
  ///   - query: The query to restrict.
  public static func columns(_ columns: [String], _ query: FTS5Query) -> FTS5Query {
    precondition(!columns.isEmpty, "Column filter requires at least one column")
    for column in columns {
      FTS5Table.validate(column, role: "Column")
    }
    let rendered = columns.map(FTS5Table.escape).joined(separator: " ")
    return FTS5Query(rendered: "{\(rendered)} : (\(query.queryText))")
  }

  // MARK: - Combinators

  /// Matches rows satisfying both this query and `other`.
  ///
  /// Combinators always parenthesize and use explicit operators, so precedence never
  /// depends on FTS5's grammar rules: `phrase("a").and(.phrase("b")).or(.phrase("c"))`
  /// renders `(("a" AND "b") OR "c")`.
  public func and(_ other: FTS5Query) -> FTS5Query {
    FTS5Query(rendered: "(\(queryText) AND \(other.queryText))")
  }

  /// Matches rows satisfying either this query or `other`.
  public func or(_ other: FTS5Query) -> FTS5Query {
    FTS5Query(rendered: "(\(queryText) OR \(other.queryText))")
  }

  /// Matches rows satisfying this query but not `other` (FTS5's binary `NOT`).
  public func not(_ other: FTS5Query) -> FTS5Query {
    FTS5Query(rendered: "(\(queryText) NOT \(other.queryText))")
  }

  // Always double-quoted with embedded quotes doubled, so phrase text can never escape
  // its phrase or be read as FTS5 operators.
  private static func quote(_ text: String) -> String {
    "\"\(text.doublingOccurrences(of: "\""))\""
  }
}
