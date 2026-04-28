/// Core type definitions for database parameter binding and result extraction.
///
/// This file defines the fundamental closure types used throughout the database layer
/// for safely binding parameters to SQL statements and extracting results from queries.

// MARK: - Basic Binder and Stepper

extension Database {
  /// A closure that binds parameter values to a prepared SQL statement.
  ///
  /// Binders are used to safely bind values to the `?` placeholders in SQL statements.
  /// They receive a statement handle and bind values at specific parameter indices.
  ///
  /// **Important**: SQLite uses 1-based indexing for parameters. The leftmost parameter is index 1.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let binder: Database.Binder = { stmt in
  ///   try "Alice".bind(to: stmt, at: 1)
  ///   try 25.bind(to: stmt, at: 2)
  /// }
  /// try db.exec(raw: "INSERT INTO users (name, age) VALUES (?, ?)", binder: binder)
  /// ```
  ///
  /// ## See Also
  /// - ``ManagedBinder`` for automatic index management
  /// - ``Bindable`` for types that can be bound to statements
  ///
  /// - Parameter stmt: The statement handle to bind values to.
  public typealias Binder =
    @DatabaseActor @Sendable (
      _ stmt: borrowing StatementHandle
    ) throws -> Void

  /// A closure that extracts values from a prepared SQL statement's current row.
  ///
  /// Steppers are used to extract column values from query results. They're called for
  /// each row in the result set and can extract values from the current row.
  ///
  /// **Important**: SQLite uses 0-based indexing for columns. The leftmost column is index 0.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let stepper: Database.Stepper<(String, Int)> = { stmt, stop in
  ///   let name = try String.column(of: stmt, at: 0)
  ///   let age = try Int.column(of: stmt, at: 1)
  ///   return (name, age)
  /// }
  /// let users = try db.query(raw: "SELECT name, age FROM users", stepper: stepper)
  /// ```
  ///
  /// ## Stopping Iteration
  ///
  /// Set `stop` to `true` to stop iterating through rows early:
  ///
  /// ```swift
  /// let stepper: Database.Stepper<String> = { stmt, stop in
  ///   let name = try String.column(of: stmt, at: 0)
  ///   if name == "Target" {
  ///     stop = true
  ///   }
  ///   return name
  /// }
  /// ```
  ///
  /// ## See Also
  /// - ``ManagedStepper`` for automatic index management
  /// - ``Bindable`` for types that can be extracted from statements
  ///
  /// - Parameters:
  ///   - stmt: The statement handle to extract values from.
  ///   - stop: Set to `true` to stop reading rows early.
  public typealias Stepper<R> =
    @DatabaseActor @Sendable (
      _ stmt: borrowing StatementHandle,
      _ stop: inout Bool
    ) throws -> R
}

// MARK: - Managed Index

/// An automatically incrementing index for binding parameters or extracting columns.
///
/// `ManagedIndex` wraps an integer index that can be automatically incremented as you
/// bind parameters or extract columns. This eliminates the need to manually track and
/// increment indices, reducing errors and improving code readability.
///
/// ## Parameter Binding
///
/// When binding parameters, the index starts at 0 and increments to 1, 2, 3, etc.
/// (SQLite uses 1-based indexing for parameters):
///
/// ```swift
/// var index = ManagedIndex()
/// try "Alice".bind(to: stmt, at: &index)             // Binds at index 1
/// try 25.bind(to: stmt, at: &index)                  // Binds at index 2
/// try "alice@example.com".bind(to: stmt, at: &index) // Binds at index 3
/// ```
///
/// ## Column Extraction
///
/// When extracting columns, the index typically starts at 0 and increments to 1, 2, 3, etc.
/// (SQLite uses 0-based indexing for columns):
///
/// ```swift
/// var index = ManagedIndex()
/// let name = try String.column(of: stmt, at: &index)  // Reads column 0
/// let age = try Int.column(of: stmt, at: &index)      // Reads column 1
/// let email = try String.column(of: stmt, at: &index) // Reads column 2
/// ```
///
/// ## Benefits
///
/// - **Error Prevention**: No manual index tracking means no off-by-one errors
/// - **Maintainability**: Adding or removing parameters/columns doesn't require renumbering
/// - **Readability**: Code clearly shows the sequence without explicit numbers
///
/// ## See Also
/// - ``Database/ManagedBinder``
/// - ``Database/ManagedStepper``
public struct ManagedIndex {
  /// The current index value.
  ///
  /// This value is automatically incremented by binding and extraction methods.
  /// For parameter binding, it starts at 0 and increments before each bind (resulting in 1, 2, 3...).
  /// For column extraction, it starts at 0 and increments after each read (resulting in 0, 1, 2...).
  public var value: Int32

  /// Creates a new managed index.
  ///
  /// - Parameter value: Initial value of the index. Defaults to 0.
  public init(value: Int32 = 0) {
    self.value = value
  }
}

// MARK: - Managed Binder and Stepper

extension Database {
  /// A closure that binds parameter values to a statement with automatic index management.
  ///
  /// `ManagedBinder` is similar to ``Binder``, but it includes a ``ManagedIndex`` parameter
  /// that's automatically incremented as you bind values. This eliminates manual index tracking
  /// and reduces errors.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let binder: Database.ManagedBinder = { stmt, index in
  ///   try "Alice".bind(to: stmt, at: &index)             // Binds at index 1
  ///   try 25.bind(to: stmt, at: &index)                  // Binds at index 2
  ///   try "alice@example.com".bind(to: stmt, at: &index) // Binds at index 3
  /// }
  /// try db.exec(
  ///   raw: "INSERT INTO users (name, age, email) VALUES (?, ?, ?)",
  ///   binder: binder
  /// )
  /// ```
  ///
  /// ## Comparison with Binder
  ///
  /// **Without managed index** (``Binder``):
  /// ```swift
  /// { stmt in
  ///   try "Alice".bind(to: stmt, at: 1)
  ///   try 25.bind(to: stmt, at: 2)
  ///   try "alice@example.com".bind(to: stmt, at: 3)
  /// }
  /// ```
  ///
  /// **With managed index** (``ManagedBinder``):
  /// ```swift
  /// { stmt, index in
  ///   try "Alice".bind(to: stmt, at: &index)
  ///   try 25.bind(to: stmt, at: &index)
  ///   try "alice@example.com".bind(to: stmt, at: &index)
  /// }
  /// ```
  ///
  /// ## See Also
  /// - ``Binder`` for manual index management
  /// - ``ManagedIndex`` for the index type
  /// - ``Bindable`` for types that can be bound
  ///
  /// - Parameters:
  ///   - stmt: The statement handle to bind values to.
  ///   - index: A managed index that's automatically incremented by each bind operation.
  public typealias ManagedBinder =
    @DatabaseActor @Sendable (
      _ stmt: borrowing StatementHandle,
      _ index: inout ManagedIndex
    ) throws -> Void

  /// A closure that extracts values from a statement with automatic index management.
  ///
  /// `ManagedStepper` is similar to ``Stepper``, but it includes a ``ManagedIndex`` parameter
  /// that's automatically incremented as you extract values. This eliminates manual index tracking
  /// and reduces errors.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let stepper: Database.ManagedStepper<(String, Int, String)> = { stmt, index, stop in
  ///   let name = try String.column(of: stmt, at: &index)  // Reads column 0
  ///   let age = try Int.column(of: stmt, at: &index)      // Reads column 1
  ///   let email = try String.column(of: stmt, at: &index) // Reads column 2
  ///   return (name, age, email)
  /// }
  /// let users = try db.query(
  ///   raw: "SELECT name, age, email FROM users",
  ///   stepper: stepper
  /// )
  /// ```
  ///
  /// ## Comparison with Stepper
  ///
  /// **Without managed index** (``Stepper``):
  /// ```swift
  /// { stmt, stop in
  ///   let name = try String.column(of: stmt, at: 0)
  ///   let age = try Int.column(of: stmt, at: 1)
  ///   let email = try String.column(of: stmt, at: 2)
  ///   return (name, age, email)
  /// }
  /// ```
  ///
  /// **With managed index** (``ManagedStepper``):
  /// ```swift
  /// { stmt, index, stop in
  ///   let name = try String.column(of: stmt, at: &index)
  ///   let age = try Int.column(of: stmt, at: &index)
  ///   let email = try String.column(of: stmt, at: &index)
  ///   return (name, age, email)
  /// }
  /// ```
  ///
  /// ## See Also
  /// - ``Stepper`` for manual index management
  /// - ``ManagedIndex`` for the index type
  /// - ``Bindable`` for types that can be extracted
  ///
  /// - Parameters:
  ///   - stmt: The statement handle to extract values from.
  ///   - index: A managed index that's automatically incremented by each column extraction.
  ///   - stop: Set to `true` to stop reading rows early.
  public typealias ManagedStepper<R> =
    @DatabaseActor @Sendable (
      _ stmt: borrowing StatementHandle,
      _ index: inout ManagedIndex,
      _ stop: inout Bool
    ) throws -> R
}
