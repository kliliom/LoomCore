/// SQLite's `json_tree` table-valued function — one row per node of a JSON document,
/// recursing into nested containers, for use in a FROM clause.
///
/// Like ``JSONEach`` but walks the whole subtree: containers appear as their own rows
/// (with NULL ``atom(as:)``) followed by their descendants. `JSONTree` is a
/// ``TableValuedFunction``, not an ``Expression``: it names a table, not a value —
/// interpolate it in FROM position only.
///
/// ```swift
/// let data = ColumnExpression<String>("data", of: "users")
/// let node = JSONTree(data, alias: "node")
/// let paths = try await db.query(
///   "SELECT \(node.fullkey) FROM users, \(node)"
/// ) { stmt, _ in
///   try String.column(of: stmt, at: 0)
/// }
/// ```
///
/// Pass an `alias` whenever the function appears more than once in a query; without one,
/// SQLite names the table `json_tree` and the column handles qualify with that.
public struct JSONTree: TableValuedFunction {
  private let core: JSONTableCore

  /// Alias the function is joined under, as supplied at construction; `nil` uses SQLite's
  /// default table name `json_tree`.
  public var alias: String? { core.alias }

  /// Creates a `json_tree(...)` FROM-clause fragment.
  ///
  /// - Parameters:
  ///   - source: Expression yielding the JSON document to walk.
  ///   - path: Path of the subtree to walk. When `nil`, walks the whole document.
  ///   - alias: Optional alias, rendered `AS "alias"`. Must be non-empty and free of NUL
  ///     bytes.
  public init(_ source: some Expression, _ path: JSONPath? = nil, alias: String? = nil) {
    self.core = JSONTableCore(sqlName: "JSON_TREE", source: source, path: path, alias: alias)
  }

  public func append(to builder: inout SQLBuilder) {
    core.append(to: &builder)
  }

  /// The node's key: object member name (`String`), array index (`Int`), or NULL for the
  /// root.
  ///
  /// State the type with `as:` because the storage class depends on the container kind.
  /// The handle is optional-typed because the root row always reads NULL; state the key
  /// type itself, e.g. `key(as: String.self)`.
  public func key<V: Bindable>(as type: V.Type) -> ColumnExpression<V?> {
    core.column("key")
  }

  /// The node's value; the storage class varies per node, so state the type.
  public func value<V: Bindable>(as type: V.Type) -> ColumnExpression<V> {
    core.column("value")
  }

  /// Like ``value(as:)`` but NULL for arrays and objects — only scalar values.
  ///
  /// The handle is optional-typed because container rows always read NULL; state the
  /// scalar type itself, e.g. `atom(as: String.self)`.
  public func atom<V: Bindable>(as type: V.Type) -> ColumnExpression<V?> {
    core.column("atom")
  }

  /// The node's JSON type name (`'object'`, `'array'`, `'integer'`, …).
  public var type: ColumnExpression<String> {
    core.column("type")
  }

  /// Node identifier, unique within the document.
  public var id: ColumnExpression<Int> {
    core.column("id")
  }

  /// The ``id`` of the node's parent; NULL for the root.
  public var parent: ColumnExpression<Int?> {
    core.column("parent")
  }

  /// Full path to the node, e.g. `$.tags[2]`.
  public var fullkey: ColumnExpression<String> {
    core.column("fullkey")
  }

  /// Path to the node's container, e.g. `$.tags`.
  public var path: ColumnExpression<String> {
    core.column("path")
  }
}
