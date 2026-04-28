/// Database methods for executing SQL statements that don't return results.
///
/// This file provides various `exec` methods for executing SQL statements like INSERT, UPDATE,
/// DELETE, and DDL statements (CREATE TABLE, etc.). For queries that return results, use the
/// query methods instead.

import SQLite3

// MARK: - Raw Statement Execution

extension Database {
  /// Executes a SQL statement that doesn't return results, with custom parameter binding.
  ///
  /// This is the primary exec method used for executing SQL statements that modify data
  /// or perform operations without returning rows. The statement is prepared, parameters
  /// are bound using the provided binder closure, and then executed.
  ///
  /// ## When to Use
  ///
  /// Use this method for:
  /// - INSERT, UPDATE, DELETE statements
  /// - DDL statements (CREATE TABLE, DROP TABLE, ALTER TABLE, etc.)
  /// - PRAGMA statements
  /// - Other non-SELECT statements
  ///
  /// ## Example
  ///
  /// ```swift
  /// try db.exec(
  ///   raw: "INSERT INTO users (name, age) VALUES (?, ?)",
  ///   binder: { stmt in
  ///     try "Alice".bind(to: stmt, at: 1)
  ///     try 25.bind(to: stmt, at: 2)
  ///   }
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - statement: The SQL statement string with `?` placeholders for parameters.
  ///   - binder: A closure that binds values to the prepared statement parameters.
  /// - Throws: An error if statement preparation, binding, or execution fails.
  public func exec(
    raw statement: String,
    binder: Binder
  ) throws {
    let stmt = try prepare(sql: statement)
    try binder(stmt)

    try check(sqlite3_step(stmt.stmtPtr), db: stmt.dbPtr, is: SQLITE_DONE)
  }
}

extension Database {
  /// Executes a SQL statement that doesn't return results and has no parameters.
  ///
  /// This convenience method is for executing SQL statements without any parameter binding.
  /// Use this for static SQL statements that don't require dynamic values.
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Create a table
  /// try db.exec(raw: "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
  ///
  /// // Enable foreign keys
  /// try db.exec(raw: "PRAGMA foreign_keys = ON")
  ///
  /// // Delete all rows
  /// try db.exec(raw: "DELETE FROM temp_data")
  /// ```
  ///
  /// **Note**: For statements with dynamic values, use one of the other `exec` overloads
  /// to ensure safe parameter binding and prevent SQL injection.
  ///
  /// - Parameter statement: The SQL statement to execute.
  /// - Throws: An error if statement preparation or execution fails.
  @inline(__always)
  public func exec(
    raw statement: String
  ) throws {
    try exec(raw: statement, binder: { _ in })
  }
}

// MARK: - Managed Binder Convenience

extension Database {
  /// Executes a SQL statement with automatic parameter index management.
  ///
  /// This convenience method accepts a ``ManagedBinder`` that automatically manages
  /// parameter indices. The index starts at 0 and is automatically incremented for
  /// each bound parameter.
  ///
  /// ## Example
  ///
  /// ```swift
  /// try db.exec(
  ///   raw: "INSERT INTO users (name, age, email) VALUES (?, ?, ?)",
  ///   binder: { stmt, index in
  ///     try "Alice".bind(to: stmt, at: &index)             // index becomes 1
  ///     try 25.bind(to: stmt, at: &index)                  // index becomes 2
  ///     try "alice@example.com".bind(to: stmt, at: &index) // index becomes 3
  ///   }
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - statement: The SQL statement string with `?` placeholders for parameters.
  ///   - binder: A closure that binds values using automatic index management.
  /// - Throws: An error if statement preparation, binding, or execution fails.
  @inline(__always)
  public func exec(
    raw statement: String,
    binder: ManagedBinder
  ) throws {
    try exec(
      raw: statement,
      binder: { stmt in
        var index = ManagedIndex()
        try binder(stmt, &index)
      }
    )
  }
}

// MARK: - Variadic Binding

extension Database {
  /// Executes a SQL statement with inline parameter values.
  ///
  /// This convenience method provides the most concise syntax for executing statements
  /// with parameters. Simply pass the parameter values directly as arguments, and they'll
  /// be automatically bound to the statement in order.
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Insert with inline values
  /// try db.exec(
  ///   raw: "INSERT INTO users (name, age, email) VALUES (?, ?, ?)",
  ///   binding: "Alice", 25, "alice@example.com"
  /// )
  ///
  /// // Update with inline values
  /// try db.exec(
  ///   raw: "UPDATE users SET age = ? WHERE name = ?",
  ///   binding: 26, "Alice"
  /// )
  /// ```
  ///
  /// ## Type Safety
  ///
  /// All parameter values must conform to ``Bindable``. The compiler ensures type safety
  /// at compile time, and values are automatically converted to appropriate SQLite types.
  ///
  /// - Parameters:
  ///   - statement: The SQL statement string with `?` placeholders for parameters.
  ///   - firstValue: The first parameter value to bind.
  ///   - otherValues: Additional parameter values to bind, in order.
  /// - Throws: An error if statement preparation, binding, or execution fails.
  @inline(__always)
  public func exec<each Values: Bindable>(
    raw statement: String,
    binding firstValue: some Bindable,
    _ otherValues: repeat each Values
  ) throws {
    // It should be possible to skip this "packing into an array" trick
    // in the future, but current Swift 6 compiler has an issue with this
    // try exec(raw: statement, binder: { stmt, index in
    //     try firstValue.bind(to: stmt, at: &index)
    //     try repeat (each otherValues).bind(to: stmt, at: &index)
    // })

    var binders: [ManagedBinder] = [
      firstValue.managedBinder
    ]
    repeat (binders.append((each otherValues).managedBinder))
    let captureds = binders
    try exec(
      raw: statement,
      binder: { stmt, index in
        for captured in captureds {
          try captured(stmt, &index)
        }
      }
    )
  }
}

// MARK: - SQLStatement Execution

extension Database {
  /// Executes a ``SQLStatement`` with its embedded parameter bindings.
  ///
  /// This is the recommended method for executing SQL statements in most cases. It provides
  /// the best combination of safety, readability, and flexibility through Swift's string
  /// interpolation.
  ///
  /// ## String Interpolation
  ///
  /// Create statements using string interpolation for automatic, safe parameter binding:
  ///
  /// ```swift
  /// let name = "Alice"
  /// let age = 25
  /// try db.exec("INSERT INTO users (name, age) VALUES (\(name), \(age))")
  /// ```
  ///
  /// ## Raw SQL
  ///
  /// For statements without parameters, you can use ``SQLStatement/raw(_:)``:
  ///
  /// ```swift
  /// try db.exec(SQLStatement.raw("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)"))
  /// ```
  ///
  /// ## Benefits
  ///
  /// - **Type Safety**: Compile-time type checking for parameter values
  /// - **SQL Injection Prevention**: Automatic parameter binding prevents injection attacks
  /// - **Readability**: SQL reads naturally with interpolated values
  /// - **Reusability**: Statements can be constructed once and reused
  ///
  /// - Parameter statement: The SQL statement to execute with its parameter bindings.
  /// - Throws: An error if statement preparation, binding, or execution fails.
  @inline(__always)
  public func exec(
    _ statement: SQLStatement
  ) throws {
    try exec(raw: statement.sql, binder: statement.binder)
  }
}
