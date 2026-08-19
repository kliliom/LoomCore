/// SQL statement with safe parameter binding.
///
/// `SQLStatement` pairs a SQL string containing `?` placeholders with binder closures that
/// bind values into those placeholders at execution time. Build statements with string
/// interpolation — interpolated values become bound parameters, not text concatenated into SQL,
/// so user input cannot escape into the statement.
///
/// ```swift
/// let name = "Alice"
/// let minAge = 21
/// let stmt: SQLStatement = """
///   SELECT id, name FROM users
///   WHERE name = \(name) AND age > \(minAge)
///   """
/// // sql:     "SELECT id, name FROM users WHERE name = ? AND age > ?"
/// // binders: ["Alice", 21]
/// for try await row in db.query(stmt) { ... }
/// ```
///
/// ## Raw mode for trusted identifiers
///
/// Interpolating with `mode: .raw` skips parameter binding and inlines the value directly
/// into the SQL. Reserve this for SQL identifiers from trusted sources — table or column
/// names from configuration. Never use `.raw` with user input; it bypasses the parameter
/// binding that prevents SQL injection.
///
/// ```swift
/// let table = "users"  // trusted, e.g. from a configuration enum
/// let stmt: SQLStatement = "SELECT * FROM \(table, mode: .raw)"
/// ```
///
/// `.raw` requires `CustomStringConvertible`, which supplies the rendered text. A
/// `RawRepresentable` enum does not get that conformance for free — interpolate its
/// `rawValue`, not the case itself:
///
/// ```swift
/// enum Table: String { case users, posts }
/// let stmt: SQLStatement = "SELECT * FROM \(Table.users.rawValue, mode: .raw)"
/// ```
///
/// For DDL or other statements that contain no dynamic values, use ``raw(_:)``.
///
/// ## See Also
/// - ``SQLBuilder``
/// - ``Bindable``
/// - ``Expression``
public struct SQLStatement: Sendable {
  /// SQL string with `?` placeholders for each bound parameter.
  public let sql: String

  /// Binder closures, one per `?` placeholder in ``sql``, applied in order at execution.
  public let binders: [Database.ManagedBinder]

  /// Creates a statement from a SQL string and matching binders.
  ///
  /// Most call sites should build statements through string interpolation or ``raw(_:)``
  /// rather than calling this initializer directly. Use it when composing a statement
  /// from binders produced elsewhere — for example, when implementing a custom
  /// ``Expression`` that emits its own SQL fragment.
  ///
  /// - Parameters:
  ///   - sql: SQL string with one `?` for each entry in `binders`.
  ///   - binders: Binder closures invoked in order against the prepared statement.
  public init(sql: String, binders: [Database.ManagedBinder]) {
    self.sql = sql
    self.binders = binders
  }

  /// Creates a statement from raw SQL with no parameter binding.
  ///
  /// Holds exactly one statement — executing SQL that contains a second one throws
  /// ``LoomCoreErrorCode/trailingSQL``. Use ``Database/execScript(_:)`` for scripts.
  ///
  /// Use this for DDL or pragma statements that contain no dynamic values:
  ///
  /// ```swift
  /// try await db.exec(.raw("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)"))
  /// try await db.exec(.raw("PRAGMA foreign_keys = ON"))
  /// ```
  ///
  /// - Warning: Never pass user-controlled input here — `raw(_:)` bypasses parameter
  ///   binding, which is the protection against SQL injection. For dynamic values use
  ///   string interpolation; for trusted identifiers use ``ColumnExpression`` or the
  ///   `mode: .raw` interpolation modifier.
  public static func raw(_ sql: String) -> SQLStatement {
    SQLStatement(sql: sql, binders: [])
  }

  var binder: Database.Binder {
    { [binders] handle in
      var index = ManagedIndex()
      for binder in binders {
        try binder(handle, &index)
      }
    }
  }

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

  /// Creates a statement from a static string literal with no parameter binding.
  ///
  /// ```swift
  /// let stmt: SQLStatement = "SELECT * FROM users"
  /// ```
  ///
  /// For statements that include dynamic values, use string interpolation instead so the
  /// values are bound as parameters rather than spliced into the SQL.
  public init(stringLiteral value: StringLiteralType) {
    self.sql = value
    self.binders = []
  }
}

// MARK: - ExpressibleByStringInterpolation

extension SQLStatement: ExpressibleByStringInterpolation {
  public typealias StringInterpolation = SQLBuilder

  /// Creates a statement from string interpolation, binding interpolated values as parameters.
  ///
  /// Called implicitly whenever a `SQLStatement` is built from an interpolated string. The
  /// ``SQLBuilder`` collects literal SQL fragments and binders for each interpolation; this
  /// initializer joins the fragments with single spaces and carries the binders through.
  ///
  /// ```swift
  /// let name = "Alice"
  /// let stmt: SQLStatement = "SELECT * FROM users WHERE name = \(name)"
  /// // sql:     "SELECT * FROM users WHERE name = ?"
  /// // binders: ["Alice"]
  /// ```
  public init(stringInterpolation: SQLBuilder) {
    sql = stringInterpolation.sql.joined(separator: " ")
    binders = stringInterpolation.binders
  }
}

// MARK: - Operators

extension SQLStatement {
  /// Concatenates two statements, joining their SQL with a single space and appending their binders.
  ///
  /// Useful for assembling a query from reusable fragments — a base `SELECT`, a conditional
  /// `WHERE`, an optional `ORDER BY`:
  ///
  /// ```swift
  /// var stmt: SQLStatement = "SELECT id, name FROM users"
  /// if let search {
  ///   stmt = stmt + "WHERE name LIKE \(search + "%")"
  /// }
  /// stmt = stmt + "ORDER BY name"
  /// ```
  public static func + (lhs: SQLStatement, rhs: SQLStatement) -> SQLStatement {
    SQLStatement(
      sql: lhs.sql + " " + rhs.sql,
      binders: lhs.binders + rhs.binders
    )
  }

  /// Appends a statement to another in place, joining their SQL with a single space.
  ///
  /// ```swift
  /// var stmt: SQLStatement = "SELECT * FROM users"
  /// let name = "Alice"
  /// stmt += "WHERE name = \(name)"
  /// ```
  public static func += (lhs: inout SQLStatement, rhs: SQLStatement) {
    lhs = lhs + rhs
  }
}
