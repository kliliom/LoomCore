/// Typed reference to a SQL column, optionally qualified by a table name.
///
/// The generic parameter `T` carries the column's value type so it composes
/// with operators and with aggregate and scalar functions in the expression
/// DSL. Identifiers always render double-quoted (`"name"` or `"users"."name"`),
/// so reserved words and special characters are safe to use; embedded `"`
/// characters are escaped by doubling.
///
/// ```swift
/// let name = ColumnExpression<String>("name")
/// let userEmail = ColumnExpression<String>("email", of: "users")
///
/// // SQL: ( "name" = ? )
/// let predicate = name == "Alice"
///
/// // SQL: ( "users"."email" LIKE ? )
/// let match = userEmail.like("%@example.com")
/// ```
///
/// ## Validation
///
/// Column and table names are validated at construction. Empty strings and
/// strings containing a NUL byte (`\0`) trigger a precondition failure.
public struct ColumnExpression<T>: Expression {
  public typealias ExpressionValue = T

  /// Column name as supplied at construction, unquoted.
  public let columnName: String

  /// Qualifying table name as supplied at construction, unquoted; `nil` for
  /// unqualified column references.
  public let tableName: String?

  /// Creates an unqualified column reference.
  ///
  /// - Parameter columnName: Column name. Must be non-empty and free of NUL bytes.
  public init(_ columnName: String) {
    Self.validate(columnName, role: "Column")
    self.columnName = columnName
    self.tableName = nil
  }

  /// Creates a column reference qualified by a table name.
  ///
  /// - Parameters:
  ///   - columnName: Column name. Must be non-empty and free of NUL bytes.
  ///   - tableName: Table name. Must be non-empty and free of NUL bytes.
  public init(_ columnName: String, of tableName: String) {
    Self.validate(columnName, role: "Column")
    Self.validate(tableName, role: "Table")
    self.columnName = columnName
    self.tableName = tableName
  }

  public func append(to builder: inout SQLBuilder) {
    if let tableName {
      builder.appendLiteral("\(Self.escape(tableName)).\(Self.escape(columnName))")
    } else {
      builder.appendLiteral(Self.escape(columnName))
    }
  }

  private static func validate(_ name: String, role: String) {
    precondition(!name.isEmpty, "\(role) name cannot be empty")
    precondition(!name.contains("\0"), "\(role) name cannot contain a NUL byte")
  }

  private static func escape(_ name: String) -> String {
    "\"\(name.replacingOccurrences(of: "\"", with: "\"\""))\""
  }
}
