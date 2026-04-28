/// An expression that references a column in a SQL statement.
///
/// `ColumnExpression` produces a properly quoted SQL identifier for a column,
/// optionally qualified by a table name. The generic parameter `T` types the
/// column for use with operators and aggregate/scalar functions.
///
/// Identifiers are always rendered with double-quote escaping
/// (e.g. `"name"` or `"users"."name"`), making them safe to use with reserved
/// words and identifiers containing special characters. Embedded double quotes
/// are escaped by doubling.
///
/// ## Example
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
/// Column and table names are validated at construction time. The following
/// trigger a precondition failure (programmer error):
/// - Empty string
/// - Strings containing a NUL byte (`\0`)
public struct ColumnExpression<T>: Expression {
  public typealias ExpressionValue = T

  /// The column name (unquoted, as supplied at construction time).
  public let columnName: String

  /// The table name (unquoted, as supplied at construction time), or `nil`
  /// if the column reference is unqualified.
  public let tableName: String?

  /// Creates an unqualified column reference.
  ///
  /// - Parameter columnName: The column name. Must be non-empty and free of NUL bytes.
  public init(_ columnName: String) {
    Self.validate(columnName, role: "Column")
    self.columnName = columnName
    self.tableName = nil
  }

  /// Creates a column reference qualified by a table name.
  ///
  /// - Parameters:
  ///   - columnName: The column name. Must be non-empty and free of NUL bytes.
  ///   - tableName: The table name. Must be non-empty and free of NUL bytes.
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
