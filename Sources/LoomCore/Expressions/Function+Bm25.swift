/// FTS5 `BM25()` auxiliary function that scores a matched row's relevance.
///
/// Scores are negative and lower is more relevant, so `ORDER BY` ascending returns the
/// best matches first. Without weights, `BM25()` is equivalent to the default ``FTS5Table/rank``
/// ordering; pass up to one weight per indexed column, in declaration order, to boost or
/// attenuate columns — missing trailing weights default to 1.0.
///
/// Build instances through ``FTS5Table/bm25(weights:)``:
///
/// ```swift
/// let articles = FTS5Table("articles", columns: ["title", "body"])
/// // Matches in "title" count ten times as much as matches in "body".
/// let hits = try await db.query(
///   "SELECT title FROM articles WHERE \(articles.match("swift")) ORDER BY \(articles.bm25(weights: [10, 1]))"
/// ) { stmt, _ in
///   try String.column(of: stmt, at: 0)
/// }
/// ```
///
/// Meaningful only in a statement whose WHERE clause contains a MATCH against the same
/// table; outside a full-text query the score carries no ranking information.
public struct BM25: Function {
  public typealias ExpressionValue = Double

  /// The FTS5 table being scored.
  let table: FTS5Table

  /// Per-column weights, in column declaration order; empty for unweighted scoring.
  let weights: [Double]

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("BM25(")
    table.reference.append(to: &builder)
    for weight in weights {
      builder.appendLiteral(", ")
      weight.append(to: &builder)
    }
    builder.appendLiteral(")")
  }
}

extension FTS5Table {
  /// Scores a matched row's relevance via FTS5's `BM25()`, optionally weighting columns.
  ///
  /// ```swift
  /// let articles = FTS5Table("articles", columns: ["title", "body"])
  /// let ranked = try await db.query(
  ///   "SELECT title FROM articles WHERE \(articles.match("swift")) ORDER BY \(articles.bm25(weights: [10, 1]))"
  /// ) { stmt, _ in
  ///   try String.column(of: stmt, at: 0)
  /// }
  /// ```
  ///
  /// - Parameter weights: Up to one weight per indexed column, in declaration order; empty
  ///   for unweighted scoring. Missing trailing weights default to 1.0 (SQLite's own
  ///   behavior). When this table declared its ``columns``, the count must not exceed them.
  ///
  /// > Warning: Without declared ``columns`` the count cannot be validated, and FTS5 itself
  /// > raises no error for a wrong count — it pads missing weights with 1.0 and silently
  /// > ignores extras, so a drifted weight list mis-ranks without any signal. Declare
  /// > `columns` on the table handle to catch excess weights at construction.
  public func bm25(weights: [Double] = []) -> BM25 {
    precondition(
      columns.isEmpty || weights.count <= columns.count,
      "BM25 weight count (\(weights.count)) cannot exceed FTS5 column count (\(columns.count))"
    )
    return BM25(table: self, weights: weights)
  }
}
