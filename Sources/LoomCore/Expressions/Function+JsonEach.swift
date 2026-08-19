/// SQLite's `json_each` table-valued function — one row per element of a JSON array or
/// object, for use in a FROM clause.
///
/// `JSONEach` is a ``TableValuedFunction``, not an ``Expression``: it names a table, not
/// a value — interpolate it in FROM position only. Read its rows through the typed column
/// handles (``value(as:)``, ``key(as:)``, …), which qualify themselves with the
/// function's alias.
///
/// ```swift
/// let data = ColumnExpression<String>("data", of: "users")
/// let tag = JSONEach(data, "$.tags", alias: "tag")
/// let names = try await db.query(
///   "SELECT \(tag.value(as: String.self)) FROM users, \(tag)"
/// ) { stmt, _ in
///   try String.column(of: stmt, at: 0)
/// }
/// ```
///
/// Pass an `alias` whenever the function appears more than once in a query; without one,
/// SQLite names the table `json_each` and the column handles qualify with that. Recurse
/// into nested containers with ``JSONTree`` instead.
public struct JSONEach: TableValuedFunction {
  private let core: JSONTableCore

  /// Alias the function is joined under, as supplied at construction; `nil` uses SQLite's
  /// default table name `json_each`.
  public var alias: String? { core.alias }

  /// Creates a `json_each(...)` FROM-clause fragment.
  ///
  /// - Parameters:
  ///   - source: Expression yielding the JSON document to iterate.
  ///   - path: Path of the array or object to iterate. When `nil`, iterates the root.
  ///   - alias: Optional alias, rendered `AS "alias"`. Must be non-empty and free of NUL
  ///     bytes.
  public init(_ source: some Expression, _ path: JSONPath? = nil, alias: String? = nil) {
    self.core = JSONTableCore(sqlName: "JSON_EACH", source: source, path: path, alias: alias)
  }

  public func append(to builder: inout SQLBuilder) {
    core.append(to: &builder)
  }

  /// The element's key: object member name (`String`) or array index (`Int`).
  ///
  /// State the type with `as:` because the storage class depends on the container kind.
  public func key<V: Bindable>(as type: V.Type) -> ColumnExpression<V> {
    core.column("key")
  }

  /// The element's value; the storage class varies per element, so state the type.
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

  /// The element's JSON type name (`'object'`, `'array'`, `'integer'`, …).
  public var type: ColumnExpression<String> {
    core.column("type")
  }

  /// Element identifier, unique within the document.
  public var id: ColumnExpression<Int> {
    core.column("id")
  }

  /// Full path to the element, e.g. `$.tags[2]`.
  public var fullkey: ColumnExpression<String> {
    core.column("fullkey")
  }

  /// Path to the element's container, e.g. `$.tags`.
  public var path: ColumnExpression<String> {
    core.column("path")
  }
}
