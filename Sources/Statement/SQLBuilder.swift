/// A builder for constructing SQL statements with safe parameter binding through string interpolation.
///
/// `SQLBuilder` serves as the string interpolation handler for ``SQLStatement``, enabling type-safe
/// SQL construction with automatic parameter binding. It collects SQL fragments and their associated
/// binder closures during string interpolation, preventing SQL injection vulnerabilities.
///
/// ## String Interpolation
///
/// When you create a ``SQLStatement`` using string interpolation, this builder handles the interpolation:
///
/// ```swift
/// let name = "Alice"
/// let age = 25
/// let stmt: SQLStatement = "SELECT * FROM users WHERE name = \(name) AND age = \(age)"
/// // SQLBuilder creates: "SELECT * FROM users WHERE name = ? AND age = ?"
/// // And stores binders for "Alice" and 25
/// ```
///
/// ## Manual Usage
///
/// While typically used automatically through string interpolation, you can use it manually:
///
/// ```swift
/// var builder = SQLBuilder()
/// builder.appendLiteral("SELECT * FROM users WHERE id = ")
/// builder.appendInterpolation(userId)
/// let stmt = builder.makeStatement()
/// ```
///
/// ## See Also
/// - ``SQLStatement``
/// - ``Expression``
/// - ``Bindable``
public struct SQLBuilder: StringInterpolationProtocol {
  public typealias StringLiteralType = String

  /// The SQL fragments that make up the statement.
  ///
  /// Each literal part of the SQL is stored as a separate string. These will be
  /// joined with spaces when the final statement is created.
  public var sql: [String] = []

  /// The binder closures for parameter values.
  ///
  /// Each interpolated value in the SQL statement has a corresponding binder closure
  /// that will bind the actual value to the prepared statement at execution time.
  public var binders: [Database.ManagedBinder] = []

  /// Creates a builder with reserved capacity for interpolation.
  ///
  /// This initializer is called automatically by the Swift compiler when using
  /// string interpolation. The capacity hints allow pre-allocation for efficiency.
  ///
  /// - Parameters:
  ///   - literalCapacity: Unused capacity hint for literal content.
  ///   - interpolationCount: The number of interpolated values, used to reserve capacity.
  public init(literalCapacity: Int, interpolationCount: Int) {
    sql.reserveCapacity(interpolationCount + 1)
    binders.reserveCapacity(interpolationCount)
  }

  /// Creates an empty SQL builder.
  public init() {}

  /// Appends a literal SQL fragment to the builder.
  ///
  /// This method is called automatically by the Swift compiler for each literal part
  /// of an interpolated string. Literal parts are the non-interpolated text between
  /// placeholders.
  ///
  /// ## Example
  ///
  /// In the statement `"SELECT * FROM \(table)"`, the literal "SELECT * FROM " is
  /// appended via this method.
  ///
  /// - Parameter literal: The SQL text to append.
  public mutating func appendLiteral(_ literal: StringLiteralType) {
    sql.append(literal)
  }

  /// Specifies how an interpolated value should be appended to the SQL statement.
  public enum AppendMode {
    /// Append the value as a raw SQL fragment without parameter binding.
    ///
    /// Use this for table names, column names, or SQL keywords that cannot be
    /// parameterized. **Warning**: Only use with trusted values to prevent SQL injection.
    case raw

    /// Append the value as a bound parameter (default).
    ///
    /// This mode creates a `?` placeholder and registers a binder to safely
    /// bind the value at execution time. This prevents SQL injection.
    case bind
  }

  /// Appends an interpolated value to the SQL statement.
  ///
  /// This method is called automatically by the Swift compiler for each interpolated
  /// value in a string literal. By default, values are bound as parameters (`.bind` mode)
  /// for safety. Use `.raw` mode only for SQL identifiers from trusted sources.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let table = "users"
  /// let name = "Alice"
  /// let stmt: SQLStatement = "SELECT * FROM \(table, mode: .raw) WHERE name = \(name)"
  /// // Produces: "SELECT * FROM users WHERE name = ?"
  /// ```
  ///
  /// - Parameters:
  ///   - value: The expression value to interpolate.
  ///   - mode: How to append the value (`.bind` for parameters, `.raw` for identifiers).
  public mutating func appendInterpolation(_ value: some Expression, mode: AppendMode = .bind) {
    switch mode {
    case .raw:
      switch value {
      case let value as String:
        sql.append(value)
      default:
        value.append(to: &self)
      }
    case .bind:
      value.append(to: &self)
    }
  }
}

// MARK: - Statement Construction

extension SQLBuilder {
  /// Constructs the final SQL string by joining all fragments.
  ///
  /// All SQL fragments are joined with space separators to form the complete
  /// SQL statement string with `?` placeholders for bound parameters.
  ///
  /// - Returns: The complete SQL statement string.
  func statement() -> String {
    sql.joined(separator: " ")
  }

  /// Creates a managed binder that executes all registered binders in sequence.
  ///
  /// The returned closure will bind all interpolated values to a prepared statement
  /// in the order they were added, using automatic index management.
  ///
  /// - Returns: A closure that binds all values to a statement handle.
  func binder() -> Database.ManagedBinder {
    { [binders] handle, index in
      for binder in binders {
        try binder(handle, &index)
      }
    }
  }

  /// Creates a ``SQLStatement`` from the builder's accumulated SQL and binders.
  ///
  /// This method combines the SQL fragments and binder closures into a complete
  /// ``SQLStatement`` that can be executed against a database.
  ///
  /// ## Example
  ///
  /// ```swift
  /// var builder = SQLBuilder()
  /// builder.appendLiteral("SELECT * FROM users WHERE id = ")
  /// builder.appendInterpolation(userId)
  /// let statement = builder.makeStatement()
  /// ```
  ///
  /// - Returns: A complete SQL statement ready for execution.
  public func makeStatement() -> SQLStatement {
    SQLStatement(stringInterpolation: self)
  }
}
