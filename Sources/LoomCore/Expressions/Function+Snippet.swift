/// FTS5 `SNIPPET()` auxiliary function that extracts a fragment of matched text.
///
/// Returns up to `maxTokens` tokens of the selected column surrounding the best match,
/// wrapping each matched token in `prefix`/`suffix` and marking truncation with `ellipsis`.
/// Returns `nil` when the selected column's value is NULL.
///
/// Build instances through ``FTS5Table/snippet(column:prefix:suffix:ellipsis:maxTokens:)``:
///
/// ```swift
/// let articles = FTS5Table("articles", columns: ["title", "body"])
/// let excerpts = try await db.query(
///   """
///   SELECT \(articles.snippet(column: "body", prefix: "<b>", suffix: "</b>", ellipsis: "…", maxTokens: 8))
///   FROM articles WHERE \(articles.match("swift"))
///   """
/// ) { stmt, _ in
///   try String?.column(of: stmt, at: 0)
/// }
/// ```
///
/// Meaningful only in a statement whose WHERE clause contains a MATCH against the same
/// table; outside a full-text query there are no matches to mark.
public struct Snippet: Function {
  public typealias ExpressionValue = String?

  /// The FTS5 table being excerpted.
  let table: FTS5Table

  /// 0-based index of the column to excerpt; `-1` lets FTS5 pick the best column.
  let columnIndex: Int

  /// Text inserted before each matched token.
  let prefix: String

  /// Text inserted after each matched token.
  let suffix: String

  /// Text marking truncated context at either end of the fragment.
  let ellipsis: String

  /// Maximum number of tokens in the fragment.
  let maxTokens: Int

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("SNIPPET(")
    table.reference.append(to: &builder)
    builder.appendLiteral(", ")
    columnIndex.append(to: &builder)
    builder.appendLiteral(", ")
    prefix.append(to: &builder)
    builder.appendLiteral(", ")
    suffix.append(to: &builder)
    builder.appendLiteral(", ")
    ellipsis.append(to: &builder)
    builder.appendLiteral(", ")
    maxTokens.append(to: &builder)
    builder.appendLiteral(")")
  }
}

extension FTS5Table {
  /// Extracts a highlighted fragment of a named column via FTS5's `SNIPPET()`.
  ///
  /// The column is addressed by name and resolved against this table's declared
  /// ``columns`` (SQLite itself identifies snippet columns by positional index).
  ///
  /// ```swift
  /// let articles = FTS5Table("articles", columns: ["title", "body"])
  /// let excerpts = try await db.query(
  ///   """
  ///   SELECT \(articles.snippet(column: "body", prefix: "<b>", suffix: "</b>", ellipsis: "…", maxTokens: 8))
  ///   FROM articles WHERE \(articles.match("swift"))
  ///   """
  /// ) { stmt, _ in
  ///   try String?.column(of: stmt, at: 0)
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - column: Column to excerpt. Must be declared in this table's ``columns``.
  ///   - prefix: Text inserted before each matched token.
  ///   - suffix: Text inserted after each matched token.
  ///   - ellipsis: Text marking truncated context at either end of the fragment.
  ///   - maxTokens: Maximum number of tokens in the fragment. Must be between 1 and 64
  ///     (FTS5's limit).
  public func snippet(column: String, prefix: String, suffix: String, ellipsis: String, maxTokens: Int) -> Snippet {
    makeSnippet(
      columnIndex: index(of: column),
      prefix: prefix,
      suffix: suffix,
      ellipsis: ellipsis,
      maxTokens: maxTokens
    )
  }

  /// Extracts a highlighted fragment via FTS5's `SNIPPET()`, letting FTS5 pick the most
  /// relevant column.
  ///
  /// - Parameters:
  ///   - prefix: Text inserted before each matched token.
  ///   - suffix: Text inserted after each matched token.
  ///   - ellipsis: Text marking truncated context at either end of the fragment.
  ///   - maxTokens: Maximum number of tokens in the fragment. Must be between 1 and 64
  ///     (FTS5's limit).
  public func snippet(prefix: String, suffix: String, ellipsis: String, maxTokens: Int) -> Snippet {
    makeSnippet(columnIndex: -1, prefix: prefix, suffix: suffix, ellipsis: ellipsis, maxTokens: maxTokens)
  }

  private func makeSnippet(
    columnIndex: Int,
    prefix: String,
    suffix: String,
    ellipsis: String,
    maxTokens: Int
  ) -> Snippet {
    precondition((1...64).contains(maxTokens), "Snippet maxTokens must be between 1 and 64")
    return Snippet(
      table: self,
      columnIndex: columnIndex,
      prefix: prefix,
      suffix: suffix,
      ellipsis: ellipsis,
      maxTokens: maxTokens
    )
  }
}
