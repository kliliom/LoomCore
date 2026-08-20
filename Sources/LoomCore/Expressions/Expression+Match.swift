// MARK: - Full-Text Match Operator

/// Full-text match expression rendering SQL `MATCH` against an FTS5 table or column.
///
/// Build instances through ``FTS5Table/match(_:)->MatchExpression<R>`` for whole-table queries or
/// `match(_:)` on a `String`-typed ``ColumnExpression`` to search a single column —
/// direct construction is not offered, because the left-hand side of `MATCH` must be an
/// FTS5 table or column identifier.
///
/// ```swift
/// let articles = FTS5Table("articles")
/// let hits = try await db.query(
///   "SELECT title FROM articles WHERE \(articles.match("swift AND database"))"
/// ) { stmt, _ in
///   try String.column(of: stmt, at: 0)
/// }
/// ```
///
/// The query text is always a bound parameter — it is user data, like a LIKE pattern —
/// so statements differing only in their search text share one prepared-statement cache
/// entry. (Contrast with ``JSONPath``, which inlines because expression-index matching
/// requires a literal token; no such optimization applies to MATCH.)
///
/// A syntactically invalid query, or a MATCH against a table that is not an FTS5 table,
/// fails when SQLite executes the statement and surfaces as a thrown ``LoomError``.
///
/// > Important: A match expression composes with `&&` only. Because it is `Bool`-valued it
/// > also type-checks under `||` and prefix `!`, but SQLite requires `MATCH` to be
/// > consumable by the FTS5 index planner, so those statements always throw
/// > "unable to use function MATCH in the requested context" at execution. Express
/// > alternatives and exclusions inside the query itself — ``FTS5Query/or(_:)`` and
/// > ``FTS5Query/not(_:)`` — rather than around it.
public struct MatchExpression<Right: Expression>: Expression where Right.ExpressionValue == String {
  public typealias ExpressionValue = Bool

  /// The left-hand side: an FTS5 table or column identifier.
  let left: any Expression

  /// The right-hand side query, bound at execution time.
  let right: Right

  init(left: any Expression, right: Right) {
    self.left = left
    self.right = right
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("(")
    left.append(to: &builder)
    builder.appendLiteral("MATCH")
    right.append(to: &builder)
    builder.appendLiteral(")")
  }
}

extension FTS5Table {
  /// Tests whether a row matches an FTS5 query, searching all indexed columns.
  ///
  /// The query uses [FTS5 query syntax](https://sqlite.org/fts5.html#full_text_query_syntax)
  /// — `swift AND database`, `"exact phrase"`, `title : swift` — and is bound as a
  /// parameter, so it can never escape the `MATCH` operand into SQL. Binding does not
  /// sandbox the FTS5 grammar itself, though: raw user input gains column filters over
  /// every indexed column, including ones your UI never displays. Pass user text through
  /// only when all indexed columns are meant to be searchable; otherwise build the query
  /// with ``FTS5Query`` (phrase text is inert) or scope the search to a single column.
  /// Invalid syntax throws a ``LoomError`` at execution; to build queries that are correct
  /// by construction, use ``match(_:)-(FTS5Query)`` instead.
  ///
  /// ```swift
  /// let articles = FTS5Table("articles")
  /// let userInput = "swift database"
  /// let hits = try await db.query(
  ///   "SELECT title FROM articles WHERE \(articles.match(userInput))"
  /// ) { stmt, _ in
  ///   try String.column(of: stmt, at: 0)
  /// }
  /// ```
  public func match<R: Expression>(_ query: R) -> MatchExpression<R> where R.ExpressionValue == String {
    MatchExpression(left: reference, right: query)
  }

  /// Tests whether a row matches a typed ``FTS5Query``, searching all indexed columns.
  ///
  /// ```swift
  /// let articles = FTS5Table("articles")
  /// let query = FTS5Query.phrase("swift concurrency").or(.prefix("actor"))
  /// let hits = try await db.query(
  ///   "SELECT title FROM articles WHERE \(articles.match(query))"
  /// ) { stmt, _ in
  ///   try String.column(of: stmt, at: 0)
  /// }
  /// ```
  public func match(_ query: FTS5Query) -> MatchExpression<String> {
    MatchExpression(left: reference, right: query.queryText)
  }
}

// On ColumnExpression rather than all String-valued expressions: a MATCH left-hand side
// must literally be an FTS5 column identifier, so e.g. Upper(column).match(...) should
// not type-check.
extension ColumnExpression where T == String {
  /// Tests whether this FTS5 column matches an FTS5 query.
  ///
  /// Equivalent to a whole-table ``FTS5Table/match(_:)->MatchExpression<R>`` with a column filter
  /// restricting the query to this column.
  ///
  /// ```swift
  /// let title = ColumnExpression<String>("title")
  /// let hits = try await db.query(
  ///   "SELECT title FROM articles WHERE \(title.match("swift"))"
  /// ) { stmt, _ in
  ///   try String.column(of: stmt, at: 0)
  /// }
  /// ```
  public func match<R: Expression>(_ query: R) -> MatchExpression<R> where R.ExpressionValue == String {
    MatchExpression(left: self, right: query)
  }

  /// Tests whether this FTS5 column matches a typed ``FTS5Query``.
  ///
  /// ```swift
  /// let title = ColumnExpression<String>("title")
  /// let hits = try await db.query(
  ///   "SELECT title FROM articles WHERE \(title.match(.phrase("swift concurrency")))"
  /// ) { stmt, _ in
  ///   try String.column(of: stmt, at: 0)
  /// }
  /// ```
  public func match(_ query: FTS5Query) -> MatchExpression<String> {
    MatchExpression(left: self, right: query.queryText)
  }
}
