/// Handle to an FTS5 virtual table for building full-text search expressions.
///
/// An `FTS5Table` names an existing FTS5 virtual table so its full-text operators —
/// ``match(_:)-(FTS5Query)``, ``rank``, ``bm25(weights:)``, ``snippet(column:prefix:suffix:ellipsis:maxTokens:)``,
/// and ``highlight(column:prefix:suffix:)`` — can participate in the expression DSL. It does
/// not create the table; declare FTS5 tables with plain SQL:
///
/// ```swift
/// try await db.exec(raw: "CREATE VIRTUAL TABLE articles USING fts5(title, body)")
///
/// let articles = FTS5Table("articles", columns: ["title", "body"])
/// let hits = try await db.query(
///   "SELECT title FROM articles WHERE \(articles.match("swift")) ORDER BY \(articles.rank)"
/// ) { stmt, _ in
///   try String.column(of: stmt, at: 0)
/// }
/// ```
///
/// Pass `columns` (in declaration order) to address columns by name in
/// ``snippet(column:prefix:suffix:ellipsis:maxTokens:)`` and ``highlight(column:prefix:suffix:)``,
/// which SQLite identifies by positional index. The list is optional — matching and ranking
/// work without it.
///
/// Unlike ``Expression``, an `FTS5Table` names a table, not a value, so it deliberately does
/// not conform to `Expression` and cannot type-check inside SELECT lists or predicates on its
/// own. (Same reasoning as ``TableValuedFunction``.)
///
/// ## Validation
///
/// The table name and column names are validated at construction. Empty strings, strings
/// containing a NUL byte (`\0`), and duplicate column names trigger a precondition failure.
///
/// > Warning: The `columns` list is trusted — nothing checks it against the live table.
/// > SQLite addresses snippet/highlight columns by position, so a declaration whose *order*
/// > drifts from the schema (say, a migration inserts or reorders a column) resolves to a
/// > valid but wrong index and silently excerpts the wrong column — wrong data, no error.
/// > Pin the declaration to the live schema with ``verifyColumns(on:)`` in an integration
/// > test or at startup.
///
/// ## See Also
/// - ``FTS5Query``
/// - ``MatchExpression``
public struct FTS5Table: Sendable, Hashable {
  /// Table name as supplied at construction, unquoted.
  public let tableName: String

  /// Indexed column names in declaration order; empty when not declared.
  public let columns: [String]

  // Quoted identifier rendering, computed once here: a table handle is built once but
  // appended on every execution of every query it appears in (mirrors ColumnExpression).
  let renderedSQL: String

  /// Creates a handle to an existing FTS5 virtual table.
  ///
  /// - Parameters:
  ///   - tableName: Table name. Must be non-empty and free of NUL bytes.
  ///   - columns: Indexed column names in declaration order. Each must be non-empty, free
  ///     of NUL bytes, and unique. Required only for ``snippet(column:prefix:suffix:ellipsis:maxTokens:)``,
  ///     ``highlight(column:prefix:suffix:)``, and weight-count validation in ``bm25(weights:)``.
  public init(_ tableName: String, columns: [String] = []) {
    Self.validate(tableName, role: "Table")
    for column in columns {
      Self.validate(column, role: "Column")
    }
    precondition(Set(columns).count == columns.count, "FTS5 column names must be unique")
    self.tableName = tableName
    self.columns = columns
    self.renderedSQL = Self.escape(tableName)
  }

  /// Resolves a declared column name to its 0-based FTS5 column index.
  func index(of column: String) -> Int {
    guard let index = columns.firstIndex(of: column) else {
      preconditionFailure("Column '\(column)' is not declared on FTS5 table '\(tableName)'")
    }
    return index
  }

  static func validate(_ name: String, role: String) {
    precondition(!name.isEmpty, "\(role) name cannot be empty")
    precondition(!name.contains("\0"), "\(role) name cannot contain a NUL byte")
  }

  static func escape(_ name: String) -> String {
    "\"\(name.doublingOccurrences(of: "\""))\""
  }
}

// Carries the table name into expression position (the MATCH left-hand side and the first
// argument of the FTS5 auxiliary functions). Internal: only identifier-shaped things built
// by FTS5Table may appear there, so direct construction is not offered.
struct FTS5TableReference: Expression {
  typealias ExpressionValue = String

  let renderedSQL: String

  func append(to builder: inout SQLBuilder) {
    builder.appendLiteral(renderedSQL)
  }
}

extension FTS5Table {
  var reference: FTS5TableReference {
    FTS5TableReference(renderedSQL: renderedSQL)
  }

  /// The FTS5 hidden `rank` column: the row's relevance score within a full-text query.
  ///
  /// Scores are negative and lower is more relevant, so `ORDER BY` ascending returns the
  /// best matches first. Outside a statement containing a MATCH against this table the
  /// column is NULL — hence the optional value type.
  ///
  /// ```swift
  /// let articles = FTS5Table("articles")
  /// let best = try await db.query(
  ///   "SELECT title FROM articles WHERE \(articles.match("swift")) ORDER BY \(articles.rank)"
  /// ) { stmt, _ in
  ///   try String.column(of: stmt, at: 0)
  /// }
  /// ```
  public var rank: ColumnExpression<Double?> {
    ColumnExpression("rank", of: tableName)
  }

  /// Verifies that this handle's declaration matches the live table's schema.
  ///
  /// ``snippet(column:prefix:suffix:ellipsis:maxTokens:)`` and
  /// ``highlight(column:prefix:suffix:)`` resolve column names positionally against the
  /// declared ``columns``, so a declaration that drifts from the schema silently excerpts
  /// the wrong column. Call this from an integration test or at startup to fail loudly
  /// instead:
  ///
  /// ```swift
  /// let articles = FTS5Table("articles", columns: ["title", "body"])
  /// try await articles.verifyColumns(on: db)
  /// ```
  ///
  /// When the handle declared ``columns``, they must equal the table's columns exactly —
  /// same names, same order. Without a declaration, only the table's existence is checked.
  ///
  /// - Throws: ``LoomError`` with ``LoomCoreErrorCode/schemaMismatch`` when the table does
  ///   not exist or the declared columns disagree with the live schema.
  public func verifyColumns(on db: Database) async throws {
    let live = try await db.tableInfo(tableName).map(\.name)
    guard !live.isEmpty else {
      throw LoomError.core(
        .schemaMismatch,
        message: "FTS5 table '\(tableName)' does not exist"
      )
    }
    guard columns.isEmpty || columns == live else {
      throw LoomError.core(
        .schemaMismatch,
        message: "FTS5 table '\(tableName)' declares columns \(columns) but the live schema has \(live)"
      )
    }
  }
}
