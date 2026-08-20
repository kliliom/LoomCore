/// FTS5 `HIGHLIGHT()` auxiliary function that returns a column's full text with matches
/// marked.
///
/// Returns the complete value of the selected column, wrapping each matched token in
/// `prefix`/`suffix`. Returns `nil` when the column's value is NULL. To excerpt a bounded
/// fragment instead of the full text, use ``Snippet``.
///
/// Build instances through ``FTS5Table/highlight(column:prefix:suffix:)``:
///
/// ```swift
/// let articles = FTS5Table("articles", columns: ["title", "body"])
/// let marked = try await db.query(
///   """
///   SELECT \(articles.highlight(column: "title", prefix: "<b>", suffix: "</b>"))
///   FROM articles WHERE \(articles.match("swift"))
///   """
/// ) { stmt, _ in
///   try String?.column(of: stmt, at: 0)
/// }
/// ```
///
/// Meaningful only in a statement whose WHERE clause contains a MATCH against the same
/// table; outside a full-text query there are no matches to mark.
public struct Highlight: Function {
  public typealias ExpressionValue = String?

  /// The FTS5 table being highlighted.
  let table: FTS5Table

  /// 0-based index of the column to highlight.
  let columnIndex: Int

  /// Text inserted before each matched token.
  let prefix: String

  /// Text inserted after each matched token.
  let suffix: String

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("HIGHLIGHT(")
    table.reference.append(to: &builder)
    builder.appendLiteral(", ")
    columnIndex.append(to: &builder)
    builder.appendLiteral(", ")
    prefix.append(to: &builder)
    builder.appendLiteral(", ")
    suffix.append(to: &builder)
    builder.appendLiteral(")")
  }
}

extension FTS5Table {
  /// Returns a named column's full text with matches marked, via FTS5's `HIGHLIGHT()`.
  ///
  /// The column is addressed by name and resolved against this table's declared
  /// ``columns`` (SQLite itself identifies highlight columns by positional index). Unlike
  /// ``snippet(column:prefix:suffix:ellipsis:maxTokens:)`` there is no auto-column
  /// variant — FTS5's `highlight()` requires an explicit column.
  ///
  /// ```swift
  /// let articles = FTS5Table("articles", columns: ["title", "body"])
  /// let marked = try await db.query(
  ///   """
  ///   SELECT \(articles.highlight(column: "title", prefix: "<b>", suffix: "</b>"))
  ///   FROM articles WHERE \(articles.match("swift"))
  ///   """
  /// ) { stmt, _ in
  ///   try String?.column(of: stmt, at: 0)
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - column: Column to highlight. Must be declared in this table's ``columns``.
  ///   - prefix: Text inserted before each matched token.
  ///   - suffix: Text inserted after each matched token.
  public func highlight(column: String, prefix: String, suffix: String) -> Highlight {
    Highlight(table: self, columnIndex: index(of: column), prefix: prefix, suffix: suffix)
  }
}
