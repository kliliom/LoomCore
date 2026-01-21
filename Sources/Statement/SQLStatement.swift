/// A SQL statement with safe parameter binding.
///
/// `SQLStatement` represents a complete SQL statement consisting of a SQL string with
/// parameter placeholders (`?`) and associated binder closures that safely bind values
/// to those parameters at execution time.
///
/// ## Creating Statements
///
/// The most convenient way to create statements is through string interpolation:
///
/// ```swift
/// let name = "Alice"
/// let age = 25
/// let stmt: SQLStatement = "SELECT * FROM users WHERE name = \(name) AND age > \(age)"
/// // Produces: "SELECT * FROM users WHERE name = ? AND age > ?"
/// // With binders for "Alice" and 25
/// ```
///
/// For raw SQL without parameter binding:
///
/// ```swift
/// let stmt = SQLStatement.raw("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
/// ```
///
/// ## Type Safety
///
/// String interpolation automatically creates parameter bindings for ``Bindable`` types,
/// ensuring type-safe conversion and preventing SQL injection vulnerabilities:
///
/// ```swift
/// let userInput = "'; DROP TABLE users; --"
/// let stmt: SQLStatement = "SELECT * FROM users WHERE name = \(userInput)"
/// // Safely bound as parameter, not embedded in SQL
/// ```
///
/// ## Raw Mode for Identifiers
///
/// Use raw mode for table/column names from trusted sources:
///
/// ```swift
/// let table = "users"  // From trusted configuration
/// let stmt: SQLStatement = "SELECT * FROM \(table, mode: .raw)"
/// ```
///
/// ## See Also
/// - ``SQLBuilder``
/// - ``Bindable``
/// - ``Expression``
public struct SQLStatement: Sendable {
  /// The SQL string with `?` placeholders for parameters.
  ///
  /// This is the complete SQL statement that will be prepared by SQLite.
  /// Parameter placeholders use the `?` syntax, which are bound using the ``binders``.
  public let sql: String

  /// The binder closures that bind values to parameters.
  ///
  /// Each binder corresponds to a `?` placeholder in the ``sql`` string.
  /// Binders are executed in order when the statement is prepared and executed.
  public let binders: [Database.ManagedBinder]

  /// Creates a SQL statement with explicit SQL string and binders.
  ///
  /// This initializer is typically not called directly. Use string interpolation
  /// or ``raw(_:)`` instead for most cases.
  ///
  /// - Parameters:
  ///   - sql: The SQL string with `?` placeholders.
  ///   - binders: The binder closures for each parameter.
  public init(sql: String, binders: [Database.ManagedBinder]) {
    self.sql = sql
    self.binders = binders
  }

  /// Creates a raw SQL statement without parameter binding.
  ///
  /// Use this for SQL statements that don't require parameter binding, such as
  /// DDL statements (CREATE TABLE, DROP TABLE, etc.) or queries without dynamic values.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let stmt = SQLStatement.raw("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
  /// let stmt2 = SQLStatement.raw("PRAGMA foreign_keys = ON")
  /// ```
  ///
  /// **Warning**: Do not use this with user input or untrusted data, as it bypasses
  /// parameter binding and can lead to SQL injection vulnerabilities.
  ///
  /// - Parameter sql: The complete SQL statement without placeholders.
  /// - Returns: A SQL statement with no binders.
  public static func raw(_ sql: String) -> SQLStatement {
    SQLStatement(sql: sql, binders: [])
  }

  /// Creates a binder closure that executes all parameter bindings.
  ///
  /// This property constructs a ``Database/Binder`` that starts with index 0 and
  /// sequentially binds all parameter values to the prepared statement.
  ///
  /// - Returns: A closure that binds all parameters starting from index 0.
  var binder: Database.Binder {
    { [binders] handle in
      var index = ManagedIndex()
      for binder in binders {
        try binder(handle, &index)
      }
    }
  }

  /// Creates a managed binder closure that continues from a given index.
  ///
  /// This property constructs a ``Database/ManagedBinder`` that can be composed
  /// with other binders, continuing from the current managed index.
  ///
  /// - Returns: A closure that binds all parameters with managed index continuation.
  var managedBinder: Database.ManagedBinder {
    { [binders] stmt, index in
      for binder in binders {
        try binder(stmt, &index)
      }
    }
  }
}

// MARK: - ExpressibleByStringLiteral

extension SQLStatement: ExpressibleByStringLiteral {
  public typealias StringLiteralType = String

  /// Creates a SQL statement from a string literal without parameter binding.
  ///
  /// This initializer allows you to create simple SQL statements using string literals.
  /// The resulting statement has no parameter binders.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let stmt: SQLStatement = "SELECT * FROM users"
  /// ```
  ///
  /// **Note**: For statements with dynamic values, use string interpolation instead
  /// to ensure safe parameter binding.
  ///
  /// - Parameter value: The SQL string.
  public init(stringLiteral value: StringLiteralType) {
    self.sql = value
    self.binders = []
  }
}

// MARK: - ExpressibleByStringInterpolation

extension SQLStatement: ExpressibleByStringInterpolation {
  public typealias StringInterpolation = SQLBuilder

  /// Creates a SQL statement from string interpolation with parameter binding.
  ///
  /// This initializer is called automatically when you use string interpolation
  /// to create a ``SQLStatement``. It combines the SQL fragments and binders
  /// from the ``SQLBuilder`` into a complete statement.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let name = "Alice"
  /// let stmt: SQLStatement = "SELECT * FROM users WHERE name = \(name)"
  /// // sql: "SELECT * FROM users WHERE name = ?"
  /// // binders: [closure that binds "Alice"]
  /// ```
  ///
  /// - Parameter stringInterpolation: The builder containing SQL fragments and binders.
  public init(stringInterpolation: SQLBuilder) {
    sql = stringInterpolation.sql.joined(separator: " ")
    binders = stringInterpolation.binders
  }
}
