/// Type that can be bound as a SQLite statement parameter or extracted from a result column.
///
/// Conforming types participate in the type-safe statement API: they can be bound to `?`
/// placeholders, read out of result rows, and composed into `Expression` trees. Every
/// `Bindable` is also an `Expression<Self>`, so literal values can appear directly in
/// expression DSL code.
///
/// ## Indexing
///
/// SQLite's indexing is asymmetric and `Bindable` preserves it:
/// - **Parameters**: 1-based — the leftmost `?` is index `1`.
/// - **Columns**: 0-based — the leftmost result column is index `0`.
///
/// The `ManagedIndex` overloads handle this automatically: parameter binders increment
/// *before* binding, column readers increment *after* reading.
///
/// ## Conformance
///
/// A conforming type implements four members:
///
/// ```swift
/// struct Username {
///   var rawValue: String
/// }
///
/// extension Username: Bindable {
///   static var defaultSQLStorageType: String { "TEXT" }
///
///   static func bind(to stmt: borrowing StatementHandle, value: Username, at index: Int32) throws {
///     try value.rawValue.bind(to: stmt, at: index)
///   }
///
///   static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Username {
///     Username(rawValue: try String.column(of: stmt, at: index))
///   }
///
///   func asSQLLiteral() throws -> String { try rawValue.asSQLLiteral() }
/// }
/// ```
public protocol Bindable: Expression<Self> & Sendable {
  /// Binds `value` to the parameter at a 1-based `index` in `stmt`.
  ///
  /// Use inside a `Database.Binder` closure when binding parameters by explicit position.
  ///
  /// ```swift
  /// try await db.exec(raw: "INSERT INTO users (name, age) VALUES (?, ?)") { stmt in
  ///   try String.bind(to: stmt, value: "Alice", at: 1)
  ///   try Int.bind(to: stmt, value: 30, at: 2)
  /// }
  /// ```
  @DatabaseActor
  static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws

  /// Reads the column at a 0-based `index` from the current row of `stmt`.
  ///
  /// Use inside a `Database.Stepper` closure when reading columns by explicit position.
  ///
  /// ```swift
  /// struct User { let name: String; let age: Int }
  ///
  /// let users = try await db.query(raw: "SELECT name, age FROM users") { stmt, _ in
  ///   let name = try String.column(of: stmt, at: 0)
  ///   let age = try Int.column(of: stmt, at: 1)
  ///   return User(name: name, age: age)
  /// }
  /// ```
  ///
  /// - Throws: `LoomError` if the column is NULL and `Self` is non-optional, or if the
  ///   stored value cannot be coerced to `Self`.
  ///
  /// - Note: Read each result column with a single type. Readers validate the column's storage
  ///   class, and reading a column as `Data` or a `Codable` type converts the underlying value
  ///   to a BLOB in place, so reading the same index again as another type can throw
  ///   `LoomError.core(.typeMappingFailed, …)`. To read one value as two types, select the
  ///   column twice.
  @DatabaseActor
  static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self

  /// Renders the value as a SQL literal — `'Alice'`, `42`, `NULL`, `x'deadbeef'`.
  ///
  /// Intended for SQL generation, debugging, and migration tooling. Prefer parameter
  /// binding for runtime queries; embedding literals built from untrusted input bypasses
  /// the binding layer that prevents SQL injection.
  func asSQLLiteral() throws -> String

  /// SQL storage type used for this Swift type in `CREATE TABLE` column definitions.
  ///
  /// ```swift
  /// String.defaultSQLStorageType  // "TEXT"
  /// Int.defaultSQLStorageType     // "INTEGER"
  /// Double.defaultSQLStorageType  // "REAL"
  /// Data.defaultSQLStorageType    // "BLOB"
  /// ```
  static var defaultSQLStorageType: String { get }
}

// MARK: - SQL Expression Building

extension Bindable {
  /// Appends `?` to `builder` and registers a binder that binds this value at execution time.
  ///
  /// Routes literal values through parameter binding rather than string interpolation,
  /// keeping expression-built SQL injection-safe by construction.
  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("?")
    builder.appendBinder(managedBinder)
  }
}

// MARK: - Managed Index Convenience (Static Methods)

extension Bindable {
  /// Binds `value` at the next parameter position, advancing `index`.
  ///
  /// Increments `index` *before* binding, so the first call binds at position `1`.
  /// Use inside a `Database.ManagedBinder` closure when binding a sequence of parameters
  /// without tracking positions manually.
  ///
  /// ```swift
  /// try await db.exec(raw: "INSERT INTO users (name, age, email) VALUES (?, ?, ?)") { stmt, index in
  ///   try String.bind(to: stmt, value: "Alice", at: &index)
  ///   try Int.bind(to: stmt, value: 30, at: &index)
  ///   try String.bind(to: stmt, value: "alice@example.com", at: &index)
  /// }
  /// ```
  @DatabaseActor
  @inline(__always)
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: inout ManagedIndex) throws {
    index.value += 1
    try bind(to: stmt, value: value, at: index.value)
  }

  /// Reads the next column, advancing `index`.
  ///
  /// Increments `index` *after* reading, so the first call reads column `0`.
  /// Use inside a `Database.ManagedStepper` closure when reading a sequence of columns
  /// without tracking positions manually.
  ///
  /// ```swift
  /// struct User { let name: String; let age: Int; let email: String }
  ///
  /// let users = try await db.query(raw: "SELECT name, age, email FROM users") { stmt, index, _ in
  ///   let name = try String.column(of: stmt, at: &index)
  ///   let age = try Int.column(of: stmt, at: &index)
  ///   let email = try String.column(of: stmt, at: &index)
  ///   return User(name: name, age: age, email: email)
  /// }
  /// ```
  @DatabaseActor
  @inline(__always)
  public static func column(of stmt: borrowing StatementHandle, at index: inout ManagedIndex) throws -> Self {
    defer { index.value += 1 }
    return try column(of: stmt, at: index.value)
  }
}

// MARK: - Instance Method Conveniences

extension Bindable {
  /// Binds this value at the 1-based parameter `index` in `stmt`.
  ///
  /// Instance-method form of the static `bind(to:value:at:)`.
  ///
  /// ```swift
  /// try await db.exec(raw: "UPDATE users SET name = ? WHERE id = ?") { stmt in
  ///   try "Alice".bind(to: stmt, at: 1)
  ///   try 42.bind(to: stmt, at: 2)
  /// }
  /// ```
  @DatabaseActor
  @inline(__always)
  public func bind(to stmt: borrowing StatementHandle, at index: Int32) throws {
    try Self.bind(to: stmt, value: self, at: index)
  }

  /// Reads the column at 0-based `index` from `stmt` and assigns it to `self`.
  ///
  /// Mutating instance form useful when destination variables are already declared.
  ///
  /// ```swift
  /// let rows = try await db.query(raw: "SELECT name, age FROM users WHERE id = 1") { stmt, _ in
  ///   var name = ""
  ///   var age = 0
  ///   try name.column(of: stmt, at: 0)
  ///   try age.column(of: stmt, at: 1)
  ///   return (name, age)
  /// }
  /// ```
  @DatabaseActor
  @inline(__always)
  public mutating func column(of stmt: borrowing StatementHandle, at index: Int32) throws {
    self = try Self.column(of: stmt, at: index)
  }

  /// Binds this value at the next parameter position, advancing `index`.
  ///
  /// Instance-method form of the static managed-index `bind`.
  ///
  /// ```swift
  /// try await db.exec(raw: "INSERT INTO users (name, age) VALUES (?, ?)") { stmt, index in
  ///   try "Alice".bind(to: stmt, at: &index)
  ///   try 30.bind(to: stmt, at: &index)
  /// }
  /// ```
  @DatabaseActor
  @inline(__always)
  public func bind(to stmt: borrowing StatementHandle, at index: inout ManagedIndex) throws {
    index.value += 1
    try Self.bind(to: stmt, value: self, at: index.value)
  }

  /// Reads the next column from `stmt` into `self`, advancing `index`.
  ///
  /// Mutating instance form of the static managed-index `column`.
  ///
  /// ```swift
  /// let rows = try await db.query(raw: "SELECT name, age FROM users") { stmt, index, _ in
  ///   var name = ""
  ///   var age = 0
  ///   try name.column(of: stmt, at: &index)
  ///   try age.column(of: stmt, at: &index)
  ///   return (name, age)
  /// }
  /// ```
  @DatabaseActor
  @inline(__always)
  public mutating func column(of stmt: borrowing StatementHandle, at index: inout ManagedIndex) throws {
    defer { index.value += 1 }
    self = try Self.column(of: stmt, at: index.value)
  }
}

// MARK: - Managed Binder Creation

extension Bindable {
  /// Closure that binds this value using a managed index, captured by value.
  ///
  /// Used by `SQLBuilder` to defer binding until the composed statement is executed.
  /// Each interpolated value in an expression contributes one such closure to the
  /// builder's binder list, alongside the `?` it appends to the SQL text.
  public var managedBinder: Database.ManagedBinder {
    { stmt, index in
      try Self.bind(to: stmt, value: self, at: &index)
    }
  }
}
