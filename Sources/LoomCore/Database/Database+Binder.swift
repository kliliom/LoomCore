// MARK: - Basic Binder and Stepper

extension Database {
  /// Binds parameter values to a prepared SQL statement.
  ///
  /// SQLite uses 1-based indexing for parameters — the leftmost `?` is index 1.
  ///
  /// ```swift
  /// let binder: Database.Binder = { stmt in
  ///   try "Alice".bind(to: stmt, at: 1)
  ///   try 25.bind(to: stmt, at: 2)
  /// }
  /// try db.exec(raw: "INSERT INTO users (name, age) VALUES (?, ?)", binder: binder)
  /// ```
  ///
  /// See ``ManagedBinder`` for automatic index management and ``Bindable`` for the
  /// types that can be bound.
  public typealias Binder =
    @DatabaseActor @Sendable (
      _ stmt: borrowing StatementHandle
    ) throws -> Void

  /// Extracts values from the current row of a prepared SQL statement.
  ///
  /// SQLite uses 0-based indexing for columns — the leftmost column is index 0. The
  /// closure runs once per result row; set `stop` to `true` to halt iteration before
  /// the result set is exhausted.
  ///
  /// ```swift
  /// let stepper: Database.Stepper<(String, Int)> = { stmt, _ in
  ///   let name = try String.column(of: stmt, at: 0)
  ///   let age = try Int.column(of: stmt, at: 1)
  ///   return (name, age)
  /// }
  /// let users = try db.query(raw: "SELECT name, age FROM users", stepper: stepper)
  /// ```
  ///
  /// Stopping early once a sentinel row is found:
  ///
  /// ```swift
  /// let stepper: Database.Stepper<String> = { stmt, stop in
  ///   let name = try String.column(of: stmt, at: 0)
  ///   if name == "Target" { stop = true }
  ///   return name
  /// }
  /// ```
  ///
  /// See ``ManagedStepper`` for automatic index management.
  public typealias Stepper<R> =
    @DatabaseActor @Sendable (
      _ stmt: borrowing StatementHandle,
      _ stop: inout Bool
    ) throws -> R
}

// MARK: - Managed Index

/// Auto-incrementing index for binding parameters or extracting columns.
///
/// Wraps an integer that advances as values are bound or read, so adding or removing
/// a parameter or column doesn't require renumbering every position downstream.
///
/// ## Parameter binding
///
/// Starts at 0 and increments *before* each bind, producing 1, 2, 3, … to match
/// SQLite's 1-based parameter numbering:
///
/// ```swift
/// var index = ManagedIndex()
/// try "Alice".bind(to: stmt, at: &index)             // binds at 1
/// try 25.bind(to: stmt, at: &index)                  // binds at 2
/// try "alice@example.com".bind(to: stmt, at: &index) // binds at 3
/// ```
///
/// ## Column extraction
///
/// Starts at 0 and increments *after* each read, producing 0, 1, 2, … to match
/// SQLite's 0-based column numbering:
///
/// ```swift
/// var index = ManagedIndex()
/// let name = try String.column(of: stmt, at: &index)  // reads column 0
/// let age = try Int.column(of: stmt, at: &index)      // reads column 1
/// let email = try String.column(of: stmt, at: &index) // reads column 2
/// ```
public struct ManagedIndex {
  /// Current position, advanced by binding and extraction operations.
  public var value: Int32

  /// Creates a managed index starting at `value`.
  public init(value: Int32 = 0) {
    self.value = value
  }
}

// MARK: - Managed Binder and Stepper

extension Database {
  /// Binds parameter values to a statement with automatic index management.
  ///
  /// Variant of ``Binder`` that takes a ``ManagedIndex`` instead of explicit positions.
  /// The index advances on every bind, so reordering or inserting parameters doesn't
  /// require renumbering.
  ///
  /// ```swift
  /// let binder: Database.ManagedBinder = { stmt, index in
  ///   try "Alice".bind(to: stmt, at: &index)
  ///   try 25.bind(to: stmt, at: &index)
  ///   try "alice@example.com".bind(to: stmt, at: &index)
  /// }
  /// try db.exec(
  ///   raw: "INSERT INTO users (name, age, email) VALUES (?, ?, ?)",
  ///   binder: binder
  /// )
  /// ```
  public typealias ManagedBinder =
    @DatabaseActor @Sendable (
      _ stmt: borrowing StatementHandle,
      _ index: inout ManagedIndex
    ) throws -> Void

  /// Extracts values from a statement with automatic index management.
  ///
  /// Variant of ``Stepper`` that takes a ``ManagedIndex`` instead of explicit positions.
  /// The index advances on every column read. Set `stop` to `true` to halt iteration
  /// early.
  ///
  /// ```swift
  /// let stepper: Database.ManagedStepper<(String, Int, String)> = { stmt, index, _ in
  ///   let name = try String.column(of: stmt, at: &index)
  ///   let age = try Int.column(of: stmt, at: &index)
  ///   let email = try String.column(of: stmt, at: &index)
  ///   return (name, age, email)
  /// }
  /// let users = try db.query(
  ///   raw: "SELECT name, age, email FROM users",
  ///   stepper: stepper
  /// )
  /// ```
  public typealias ManagedStepper<R> =
    @DatabaseActor @Sendable (
      _ stmt: borrowing StatementHandle,
      _ index: inout ManagedIndex,
      _ stop: inout Bool
    ) throws -> R
}
