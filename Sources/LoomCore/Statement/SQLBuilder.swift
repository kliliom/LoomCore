/// String interpolation handler that builds ``SQLStatement`` values with safe parameter binding.
///
/// `SQLBuilder` collects SQL fragments and binder closures during string interpolation, producing
/// statements where interpolated values become `?` placeholders bound at execution time. This is
/// the mechanism that prevents SQL injection in interpolated statements.
///
/// ```swift
/// let name = "Alice"
/// let age = 25
/// let stmt: SQLStatement = "SELECT * FROM users WHERE name = \(name) AND age = \(age)"
/// // SQL: SELECT * FROM users WHERE name = ? AND age = ?
/// // Bound parameters: "Alice", 25
/// ```
///
/// Manual construction is supported for composing fragments programmatically:
///
/// ```swift
/// var builder = SQLBuilder()
/// builder.appendLiteral("SELECT * FROM users WHERE id = ")
/// builder.appendInterpolation(userId)
/// let stmt = builder.makeStatement()
/// ```
///
/// Use ``AppendMode/raw`` only for trusted identifiers — it bypasses parameter binding. Prefer
/// ``ColumnExpression`` for column and table references, which always renders quoted identifiers.
///
/// ## See Also
/// - ``SQLStatement``
/// - ``Expression``
/// - ``Bindable``
public struct SQLBuilder: StringInterpolationProtocol {
  public typealias StringLiteralType = String

  private(set) var sql: [String] = []

  private(set) var binders: [Database.ManagedBinder] = []

  /// Creates a builder with capacity reserved for the given interpolation count.
  ///
  /// Called automatically by the compiler when a ``SQLStatement`` is constructed from an
  /// interpolated string literal.
  public init(literalCapacity: Int, interpolationCount: Int) {
    sql.reserveCapacity(interpolationCount * 2 + 1)
    binders.reserveCapacity(interpolationCount)
  }

  /// Creates an empty builder.
  public init() {}

  /// Appends a literal SQL fragment.
  ///
  /// Called automatically by the compiler for each non-interpolated segment of an interpolated
  /// string. In `"SELECT * FROM \(table)"`, the literal `"SELECT * FROM "` is appended via this
  /// method.
  public mutating func appendLiteral(_ literal: StringLiteralType) {
    sql.append(literal)
  }

  /// Registers a binder closure that binds a value at statement execution time.
  ///
  /// Used by ``Bindable`` and ``Expression`` conformances to participate in interpolation.
  /// Application code typically interpolates values directly rather than calling this method.
  ///
  /// ```swift
  /// var builder = SQLBuilder()
  /// builder.appendLiteral("SELECT * FROM users WHERE name = ?")
  /// builder.appendBinder { stmt, index in
  ///   try String.bind("Alice", to: stmt, at: &index)
  /// }
  /// ```
  public mutating func appendBinder(_ binder: @escaping Database.ManagedBinder) {
    binders.append(binder)
  }

  /// Controls how an interpolated value is rendered into the SQL.
  public enum AppendMode {
    /// Renders the value as a raw SQL fragment with no parameter binding.
    ///
    /// Use only for trusted identifiers — table names, column names, or keywords from your own
    /// configuration. Raw mode bypasses the binding that prevents SQL injection, so user input
    /// must never reach this mode.
    case raw

    /// Renders the value as a `?` placeholder with a registered binder. The default mode.
    case bind
  }

  /// Interpolates an expression as a bound parameter.
  ///
  /// ```swift
  /// let name = "Alice"
  /// let stmt: SQLStatement = "SELECT * FROM users WHERE name = \(name)"
  /// // Produces: SELECT * FROM users WHERE name = ?
  /// ```
  public mutating func appendInterpolation(_ value: some Expression) {
    value.append(to: &self)
  }

  /// Interpolates an expression with control over binding versus raw rendering.
  ///
  /// `.bind` inserts a `?` placeholder and registers a binder; `.raw` inlines the value's
  /// `description`. Use `.raw` only for identifiers from trusted sources.
  ///
  /// ```swift
  /// let table = "users"
  /// let name = "Alice"
  /// let stmt: SQLStatement = "SELECT * FROM \(table, mode: .raw) WHERE name = \(name)"
  /// // Produces: SELECT * FROM users WHERE name = ?
  /// ```
  ///
  /// If a `.raw` value does not conform to `CustomStringConvertible`, the builder logs a warning
  /// and falls back to `.bind` mode.
  public mutating func appendInterpolation(_ value: some Expression, mode: AppendMode) {
    switch mode {
    case .raw:
      switch value {
      case let value as CustomStringConvertible:
        sql.append(value.description)
      default:
        warn(
          "Value of type \(type(of: value)) does not conform to CustomStringConvertible. Falling back to `.bind` mode."
        )
        value.append(to: &self)
      }
    case .bind:
      value.append(to: &self)
    }
  }

  /// Interpolates an optional bindable value as a bound parameter, binding `NULL` when `nil`.
  ///
  /// ```swift
  /// let nickname: String? = nil
  /// let stmt: SQLStatement = "UPDATE users SET nickname = \(nickname) WHERE id = \(userId)"
  /// // Binds NULL for the first parameter.
  /// ```
  @inline(__always)
  public mutating func appendInterpolation(_ value: (some Bindable)?) {
    return appendInterpolation(value, mode: .bind)
  }
}

// MARK: - Statement Construction

extension SQLBuilder {
  /// Builds a ``SQLStatement`` from the accumulated fragments and binders.
  ///
  /// ```swift
  /// var builder = SQLBuilder()
  /// builder.appendLiteral("SELECT * FROM users WHERE id = ")
  /// builder.appendInterpolation(userId)
  /// let statement = builder.makeStatement()
  /// ```
  public func makeStatement() -> SQLStatement {
    SQLStatement(stringInterpolation: self)
  }
}
