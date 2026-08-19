/// A FROM-clause fragment naming a table-valued function.
///
/// Unlike ``Expression``, a table-valued function produces a table, not a value. It can be
/// interpolated into a statement — in FROM position only — but deliberately does not
/// conform to `Expression`, so it cannot type-check inside SELECT lists, predicates, or
/// function arguments, where it could otherwise only fail when SQLite prepares the
/// statement.
///
/// ```swift
/// let data = ColumnExpression<String>("data", of: "users")
/// let tag = JSONEach(data, "$.tags")
/// let stmt: SQLStatement = "SELECT \(tag.value(as: String.self)) FROM users, \(tag)"
/// ```
public protocol TableValuedFunction: Sendable {
  /// Writes this fragment's SQL into `builder`, registering any parameter binders
  /// required by the arguments of the underlying function call.
  func append(to builder: inout SQLBuilder)
}

extension SQLBuilder {
  /// Interpolates a table-valued FROM fragment, rendering its SQL inline.
  public mutating func appendInterpolation(_ value: some TableValuedFunction) {
    value.append(to: &self)
  }
}

// Shared implementation of the json_each/json_tree fragments: construction rules,
// rendering, and column-handle qualification are identical; only the SQL name and the
// tree-only `parent` handle differ between the two.
struct JSONTableCore: Sendable {
  let source: any Expression

  let rootPath: JSONPath?

  /// Alias the function is joined under, as supplied at construction; `nil` uses SQLite's
  /// default table name.
  let alias: String?

  // Unquoted qualifier for the column handles; ColumnExpression quotes it on use.
  private let qualifier: String

  // "JSON_EACH" / "JSON_TREE".
  private let sqlName: String

  // Full " AS "alias"" rendering (empty without an alias), computed once at init.
  private let renderedAlias: String

  init(sqlName: String, source: some Expression, path: JSONPath?, alias: String?) {
    if let alias {
      precondition(!alias.isEmpty, "Alias name cannot be empty")
      precondition(!alias.contains("\0"), "Alias name cannot contain a NUL byte")
    }
    self.sqlName = sqlName
    self.source = source
    self.rootPath = path
    self.alias = alias
    self.qualifier = alias ?? sqlName.lowercased()
    self.renderedAlias = alias.map { " AS \"\($0.doublingOccurrences(of: "\""))\"" } ?? ""
  }

  func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("\(sqlName)(")
    source.append(to: &builder)
    if let rootPath {
      builder.appendLiteral(", \(rootPath.renderedSQL)")
    }
    builder.appendLiteral(")")
    if !renderedAlias.isEmpty {
      builder.appendLiteral(renderedAlias)
    }
  }

  func column<V: Bindable>(_ name: String) -> ColumnExpression<V> {
    ColumnExpression(name, of: qualifier)
  }
}
