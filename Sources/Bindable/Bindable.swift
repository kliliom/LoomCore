/// A type that can be bound to a SQLite statement as a parameter or extracted as a column value.
///
/// The `Bindable` protocol provides the core interface for type-safe interaction with SQLite
/// prepared statements. Types conforming to this protocol can:
/// - Be bound as parameters to prepared statements (SQL placeholders)
/// - Be extracted as column values from query results
/// - Be used in SQL expression building
/// - Be converted to SQL literal representations
///
/// ## Implementation Requirements
///
/// Conforming types must implement:
/// - ``bind(to:value:at:)-static`` - Bind a value to a statement parameter
/// - ``column(of:at:)-static`` - Extract a value from a statement column
/// - ``asSQLLiteral()`` - Convert the value to an SQL literal string
/// - ``defaultSQLStorageType`` - Specify the SQL storage type for table definitions
///
/// ## Parameter vs Column Indexing
///
/// Note the different indexing conventions:
/// - **Parameters**: 1-based indexing (leftmost parameter is index 1)
/// - **Columns**: 0-based indexing (leftmost column is index 0)
///
/// ## Example
///
/// ```swift
/// // Binding a parameter
/// try String.bind(to: stmt, value: "Hello", at: 1)
///
/// // Extracting a column
/// let value = try String.column(of: stmt, at: 0)
/// ```
public protocol Bindable: Expression<Self> & Sendable {
  /// Binds a value to a statement as a parameter.
  ///
  /// This method binds a value to a SQL parameter placeholder (?) in a prepared statement.
  /// It can be used inside ``Database/Binder`` closures.
  ///
  /// **Important**: SQLite uses 1-based indexing for parameters. The leftmost parameter is index 1.
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Bind "Hello, World!" to the first parameter
  /// try String.bind(to: stmt, value: "Hello, World!", at: 1)
  /// ```
  ///
  /// - Parameters:
  ///   - stmt: The SQLite statement handle to bind the value to.
  ///   - value: The value to bind to the parameter.
  ///   - index: The 1-based index of the parameter placeholder.
  /// - Throws: An error if the binding operation fails (e.g., invalid index, type conversion error).
  @DatabaseActor
  static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws

  /// Extracts a column value from a statement's current row.
  ///
  /// This method reads and converts a column value from the current row of a query result.
  /// It can be used inside ``Database/Stepper`` closures.
  ///
  /// **Important**: SQLite uses 0-based indexing for columns. The leftmost column is index 0.
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Extract a string from the first column
  /// let value = try String.column(of: stmt, at: 0)
  /// ```
  ///
  /// - Parameters:
  ///   - stmt: The SQLite statement handle to extract the value from.
  ///   - index: The 0-based index of the column to read.
  /// - Returns: The extracted and converted value.
  /// - Throws: An error if the extraction fails (e.g., invalid index, type conversion error, NULL value for non-optional types).
  @DatabaseActor
  static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self

  /// Converts the value to its SQL literal representation.
  ///
  /// This method produces a SQL literal string that can be directly embedded in SQL statements.
  /// For example, a string becomes `'Hello'`, an integer becomes `42`, and NULL becomes `NULL`.
  ///
  /// **Warning**: This method is primarily used for SQL generation and debugging.
  /// Prefer using parameter binding (``bind(to:value:at:)``) instead of embedding literals
  /// to prevent SQL injection vulnerabilities.
  ///
  /// - Returns: The SQL literal representation of the value.
  /// - Throws: An error if the value cannot be converted to a SQL literal.
  func asSQLLiteral() throws -> String

  /// The default SQL storage type for this type when creating table columns.
  ///
  /// This property defines the SQL type that should be used in CREATE TABLE statements
  /// for columns of this type. Common values include:
  /// - `"TEXT"` for strings
  /// - `"INTEGER"` for integers and booleans
  /// - `"REAL"` for floating-point numbers
  /// - `"BLOB"` for binary data
  ///
  /// ## Example
  ///
  /// ```swift
  /// String.defaultSQLStorageType // Returns "TEXT"
  /// Int.defaultSQLStorageType    // Returns "INTEGER"
  /// ```
  static var defaultSQLStorageType: String { get }
}

// MARK: - SQL Expression Building

extension Bindable {
  /// Appends this value to a SQL builder as a parameterized placeholder.
  ///
  /// This method is part of the SQL expression building system. It adds a parameter
  /// placeholder (`?`) to the SQL string and registers a binder closure to bind
  /// the actual value when the statement is executed.
  ///
  /// This ensures values are safely bound as parameters rather than embedded as literals,
  /// preventing SQL injection vulnerabilities.
  ///
  /// - Parameter builder: The SQL builder to append to.
  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("?")
    builder.appendBinder(managedBinder)
  }
}

// MARK: - Managed Index Convenience (Static Methods)

extension Bindable {
  /// Binds a value to a statement as a parameter using a managed index.
  ///
  /// This convenience method automatically increments the managed index after binding.
  /// This method can be used inside ``Database/ManagedBinder`` closures.
  ///
  /// Here is an example of how to bind a value to a statement:
  ///
  /// ```swift
  /// try String.bind(to: stmt, value: "Hello, World!", at: &index)
  /// ```
  ///
  /// - Parameters:
  ///   - stmt: The statement to bind the value to.
  ///   - value: The value to bind.
  ///   - index: Managed index of the parameter to bind the value to.
  @DatabaseActor
  @inline(__always)
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: inout ManagedIndex) throws {
    index.value += 1
    try bind(to: stmt, value: value, at: index.value)
  }

  /// Extracts a column value from a statement using a managed index.
  ///
  /// This convenience method automatically increments the managed index after extraction.
  /// This method can be used inside ``Database/ManagedStepper`` closures.
  ///
  /// Here is an example of how to extract a value from a statement:
  ///
  /// ```swift
  /// let value = try String.column(of: stmt, at: &index)
  /// ```
  ///
  /// - Parameters:
  ///   - stmt: The statement to extract the value from.
  ///   - index: Managed index of the column to extract the value from. Automatically incremented after extraction.
  /// - Returns: The extracted value.
  @DatabaseActor
  @inline(__always)
  public static func column(of stmt: borrowing StatementHandle, at index: inout ManagedIndex) throws -> Self {
    defer { index.value += 1 }
    return try column(of: stmt, at: index.value)
  }
}

// MARK: - Instance Method Conveniences

extension Bindable {
  /// Binds this value to a statement as a parameter.
  ///
  /// This instance method provides a convenient syntax for binding values.
  /// This method can be used inside ``Database/Binder`` closures.
  /// The leftmost SQL parameter has an index of 1.
  ///
  /// Here is an example of how to bind a value to a statement:
  ///
  /// ```swift
  /// try "Hello, World!".bind(to: stmt, at: 1)
  /// ```
  ///
  /// - Parameters:
  ///   - stmt: The statement to bind the value to.
  ///   - index: The index of the parameter to bind the value to.
  @DatabaseActor
  @inline(__always)
  public func bind(to stmt: borrowing StatementHandle, at index: Int32) throws {
    try Self.bind(to: stmt, value: self, at: index)
  }

  /// Extracts a column value from a statement and assigns it to this variable.
  ///
  /// This instance method provides a convenient mutating syntax for extracting column values.
  /// This method can be used inside ``Database/Stepper`` closures.
  /// The leftmost SQL column has an index of 0.
  ///
  /// Here is an example of how to extract a value from a statement:
  ///
  /// ```swift
  /// var value = ""
  /// try value.column(of: stmt, at: 0)
  /// // value now contains the column data
  /// ```
  ///
  /// - Parameters:
  ///   - stmt: The statement to extract the value from.
  ///   - index: The 0-based index of the column to extract the value from.
  @DatabaseActor
  @inline(__always)
  public mutating func column(of stmt: borrowing StatementHandle, at index: Int32) throws {
    self = try Self.column(of: stmt, at: index)
  }

  /// Binds this value to a statement as a parameter using a managed index.
  ///
  /// This instance method provides convenient syntax with automatic index management.
  /// This method can be used inside ``Database/ManagedBinder`` closures.
  ///
  /// Here is an example of how to bind a value to a statement:
  ///
  /// ```swift
  /// try "Hello, World!".bind(to: stmt, at: &index)
  /// ```
  ///
  /// - Parameters:
  ///   - stmt: The statement to bind the value to.
  ///   - index: Managed index of the parameter. Automatically incremented after binding.
  @DatabaseActor
  @inline(__always)
  public func bind(to stmt: borrowing StatementHandle, at index: inout ManagedIndex) throws {
    index.value += 1
    try Self.bind(to: stmt, value: self, at: index.value)
  }

  /// Extracts a column value from a statement and assigns it to this variable using a managed index.
  ///
  /// This instance method provides convenient mutating syntax with automatic index management.
  /// This method can be used inside ``Database/ManagedStepper`` closures.
  ///
  /// Here is an example of how to extract a value from a statement:
  ///
  /// ```swift
  /// var value = ""
  /// try value.column(of: stmt, at: &index)
  /// // value now contains the column data, index is incremented
  /// ```
  ///
  /// - Parameters:
  ///   - stmt: The statement to extract the value from.
  ///   - index: Managed index of the column. Automatically incremented after extraction.
  @DatabaseActor
  @inline(__always)
  public mutating func column(of stmt: borrowing StatementHandle, at index: inout ManagedIndex) throws {
    defer { index.value += 1 }
    self = try Self.column(of: stmt, at: index.value)
  }
}

// MARK: - Managed Binder Creation

extension Bindable {
  /// Returns a managed binder closure for this value.
  ///
  /// This property creates a closure that can be used to bind this value to a statement
  /// with automatic index management. The returned binder is used internally by the
  /// SQL expression building system.
  ///
  /// The binder closure captures this value and will bind it to the appropriate parameter
  /// when the SQL builder executes the statement.
  ///
  /// - Returns: A closure that binds this value using a managed index.
  public var managedBinder: Database.ManagedBinder {
    { stmt, index in
      try Self.bind(to: stmt, value: self, at: &index)
    }
  }
}
