/// Database methods for executing SQL queries that return results.
///
/// This file provides various `query` methods for executing SELECT statements and other
/// queries that return rows. For statements that don't return results (INSERT, UPDATE, DELETE),
/// use the `exec` methods instead.

import SQLite3

// MARK: - Raw Statement Queries

extension Database {
  /// Executes a SQL query that returns results, with custom parameter binding and row extraction.
  ///
  /// This is the primary query method used for executing SELECT statements and other queries
  /// that return rows. The statement is prepared, parameters are bound using the binder closure,
  /// and then each result row is extracted using the stepper closure.
  ///
  /// ## When to Use
  ///
  /// Use this method for:
  /// - SELECT queries that return data
  /// - Queries with parameters that need binding
  /// - Custom result extraction logic
  /// - Queries with PRAGMA statements that return values
  ///
  /// ## Example
  ///
  /// ```swift
  /// let users = try db.query(
  ///   raw: "SELECT name, age FROM users WHERE age > ?",
  ///   binder: { stmt in
  ///     try 18.bind(to: stmt, at: 1)
  ///   },
  ///   stepper: { stmt, stop in
  ///     let name = try String.column(of: stmt, at: 0)
  ///     let age = try Int.column(of: stmt, at: 1)
  ///     return (name, age)
  ///   }
  /// )
  /// // users: [(String, Int)]
  /// ```
  ///
  /// ## Early Termination
  ///
  /// You can stop iterating through rows by setting `stop` to `true` in the stepper:
  ///
  /// ```swift
  /// let firstMatch = try db.query(
  ///   raw: "SELECT name FROM users",
  ///   binder: { _ in },
  ///   stepper: { stmt, stop in
  ///     let name = try String.column(of: stmt, at: 0)
  ///     if name == "Target" {
  ///       stop = true
  ///     }
  ///     return name
  ///   }
  /// )
  /// ```
  ///
  /// ## Row Processing
  ///
  /// The stepper closure is called for each row in the result set. All rows are collected
  /// into an array and returned. For large result sets, consider using streaming methods
  /// or processing rows in batches.
  ///
  /// - Parameters:
  ///   - statement: The SQL query string with `?` placeholders for parameters.
  ///   - binder: A closure that binds values to the query parameters.
  ///   - stepper: A closure that extracts values from each result row.
  /// - Returns: An array of results, one element per row.
  /// - Throws: An error if query preparation, binding, execution, or extraction fails.
  public func query<R>(
    raw statement: String,
    binder: Binder,
    stepper: Stepper<R>
  ) throws -> [R] {
    let stmt = try prepare(sql: statement)
    try binder(stmt)

    var rows = [R]()
    var code = try check(sqlite3_step(stmt.stmtPtr), db: stmt.dbPtr, in: SQLITE_ROW, SQLITE_DONE)
    var stop = false
    while code == SQLITE_ROW {
      try rows.append(stepper(stmt, &stop))
      if stop {
        code = SQLITE_DONE
      } else {
        code = try check(sqlite3_step(stmt.stmtPtr), db: stmt.dbPtr, in: SQLITE_ROW, SQLITE_DONE)
      }
    }
    return rows
  }
}

extension Database {
  /// Executes a SQL query without parameters, extracting results with a stepper closure.
  ///
  /// This convenience method is for executing queries that don't require parameter binding.
  /// Use this for static SELECT statements or queries without dynamic values.
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Query all users
  /// let users = try db.query(
  ///   raw: "SELECT name, age FROM users",
  ///   stepper: { stmt, stop in
  ///     let name = try String.column(of: stmt, at: 0)
  ///     let age = try Int.column(of: stmt, at: 1)
  ///     return (name, age)
  ///   }
  /// )
  ///
  /// // Query with WHERE clause (no dynamic values)
  /// let adults = try db.query(
  ///   raw: "SELECT name FROM users WHERE age >= 18",
  ///   stepper: { stmt, stop in
  ///     try String.column(of: stmt, at: 0)
  ///   }
  /// )
  /// ```
  ///
  /// **Note**: For queries with dynamic values, use one of the other `query` overloads
  /// to ensure safe parameter binding and prevent SQL injection.
  ///
  /// - Parameters:
  ///   - statement: The SQL query string without parameters.
  ///   - stepper: A closure that extracts values from each result row.
  /// - Returns: An array of results, one element per row.
  /// - Throws: An error if query preparation, execution, or extraction fails.
  @inline(__always)
  public func query<R>(
    raw statement: String,
    stepper: Stepper<R>
  ) throws -> [R] {
    try query(
      raw: statement,
      binder: { _ in },
      stepper: stepper
    )
  }
}

// MARK: - Managed Index Convenience

extension Database {
  /// Executes a SQL query with automatic parameter and column index management.
  ///
  /// This convenience method accepts ``ManagedBinder`` and ``ManagedStepper`` closures
  /// that automatically manage indices. Parameter indices start at 0 and are incremented
  /// for each bind operation. Column indices start at 0 and are incremented for each
  /// column extraction.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let users = try db.query(
  ///   raw: "SELECT name, age, email FROM users WHERE age > ? AND status = ?",
  ///   binder: { stmt, index in
  ///     try 18.bind(to: stmt, at: &index)       // Binds at index 1
  ///     try "active".bind(to: stmt, at: &index) // Binds at index 2
  ///   },
  ///   stepper: { stmt, index, stop in
  ///     let name = try String.column(of: stmt, at: &index)  // Reads column 0
  ///     let age = try Int.column(of: stmt, at: &index)      // Reads column 1
  ///     let email = try String.column(of: stmt, at: &index) // Reads column 2
  ///     return (name, age, email)
  ///   }
  /// )
  /// ```
  ///
  /// ## Benefits
  ///
  /// - **No Manual Counting**: Indices are managed automatically
  /// - **Error Prevention**: Eliminates off-by-one errors
  /// - **Maintainability**: Adding/removing parameters or columns doesn't require renumbering
  ///
  /// - Parameters:
  ///   - statement: The SQL query string with `?` placeholders for parameters.
  ///   - binder: A closure that binds values using automatic index management.
  ///   - stepper: A closure that extracts values using automatic index management.
  /// - Returns: An array of results, one element per row.
  /// - Throws: An error if query preparation, binding, execution, or extraction fails.
  @inline(__always)
  public func query<R>(
    raw statement: String,
    binder: ManagedBinder,
    stepper: ManagedStepper<R>
  ) throws -> [R] {
    try query(
      raw: statement,
      binder: { stmt in
        var index = ManagedIndex()
        try binder(stmt, &index)
      },
      stepper: { stmt, stop in
        var index = ManagedIndex()
        return try stepper(stmt, &index, &stop)
      }
    )
  }

  /// Executes a SQL query without parameters, extracting results with automatic column index management.
  ///
  /// This convenience method is for queries without parameters, using a ``ManagedStepper``
  /// for automatic column index management.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let users = try db.query(
  ///   raw: "SELECT name, age, email FROM users",
  ///   stepper: { stmt, index, stop in
  ///     let name = try String.column(of: stmt, at: &index)  // Reads column 0
  ///     let age = try Int.column(of: stmt, at: &index)      // Reads column 1
  ///     let email = try String.column(of: stmt, at: &index) // Reads column 2
  ///     return (name, age, email)
  ///   }
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - statement: The SQL query string without parameters.
  ///   - stepper: A closure that extracts values using automatic index management.
  /// - Returns: An array of results, one element per row.
  /// - Throws: An error if query preparation, execution, or extraction fails.
  @inline(__always)
  public func query<R>(
    raw statement: String,
    stepper: ManagedStepper<R>
  ) throws -> [R] {
    try query(raw: statement, binder: { _, _ in }, stepper: stepper)
  }
}

// MARK: - Variadic Binding

extension Database {
  /// Executes a SQL query with inline parameter values and automatic index management.
  ///
  /// This convenience method provides the most concise syntax for queries with parameters.
  /// Simply pass the parameter values directly as arguments, and they'll be automatically
  /// bound to the query in order. Column extraction uses a ``ManagedStepper`` for automatic
  /// index management.
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Query with inline parameter values
  /// let users = try db.query(
  ///   raw: "SELECT name, age FROM users WHERE age > ? AND status = ?",
  ///   binding: 18, "active",
  ///   stepper: { stmt, index, stop in
  ///     let name = try String.column(of: stmt, at: &index)
  ///     let age = try Int.column(of: stmt, at: &index)
  ///     return (name, age)
  ///   }
  /// )
  ///
  /// // Query with a single parameter
  /// let admins = try db.query(
  ///   raw: "SELECT name FROM users WHERE role = ?",
  ///   binding: "admin",
  ///   stepper: { stmt, index, stop in
  ///     try String.column(of: stmt, at: &index)
  ///   }
  /// )
  /// ```
  ///
  /// ## Type Safety
  ///
  /// All parameter values must conform to ``Bindable``. The compiler ensures type safety
  /// at compile time, and values are automatically converted to appropriate SQLite types.
  ///
  /// - Parameters:
  ///   - statement: The SQL query string without parameters.
  ///   - firstValue: The first parameter value to bind.
  ///   - otherValues: Additional parameter values to bind, in order.
  ///   - stepper: A closure that extracts values using automatic index management.
  /// - Returns: An array of results, one element per row.
  /// - Throws: An error if query preparation, binding, execution, or extraction fails.
  @inline(__always)
  public func query<R, each Values: Bindable>(
    raw statement: String,
    binding firstValue: some Bindable,
    _ otherValues: repeat each Values,
    stepper: ManagedStepper<R>
  ) throws -> [R] {
    // It should be possible to skip this "packing into an array" trick
    // in the future, but current Swift 6 compiler has an issue with this
    // try query(raw: statement, binder: { stmt, index in
    //     try firstValue.bind(to: stmt, at: &index)
    //     repeat try (each Values).bind(to: stmt, value: each otherValues, at: &index)
    // }, stepper: { stmt, index, stop in
    //     try stepper(stmt, &index, &stop)
    // })

    var binders: [ManagedBinder] = [
      firstValue.managedBinder
    ]
    repeat (binders.append((each otherValues).managedBinder))
    let captureds = binders
    return try query(
      raw: statement,
      binder: { stmt, index in
        for captured in captureds {
          try captured(stmt, &index)
        }
      },
      stepper: { stmt, index, stop in
        try stepper(stmt, &index, &stop)
      }
    )
  }
}

// MARK: - SQLStatement Queries

extension Database {
  /// Executes a ``SQLStatement`` query with its embedded parameter bindings.
  ///
  /// This is the recommended method for executing queries in most cases. It provides
  /// the best combination of safety, readability, and flexibility through Swift's string
  /// interpolation.
  ///
  /// ## String Interpolation
  ///
  /// Create query statements using string interpolation for automatic, safe parameter binding:
  ///
  /// ```swift
  /// let minAge = 18
  /// let status = "active"
  /// let users = try db.query(
  ///   "SELECT name, age FROM users WHERE age > \(minAge) AND status = \(status)",
  ///   stepper: { stmt, stop in
  ///     let name = try String.column(of: stmt, at: 0)
  ///     let age = try Int.column(of: stmt, at: 1)
  ///     return (name, age)
  ///   }
  /// )
  /// ```
  ///
  /// ## Raw SQL
  ///
  /// For queries without parameters, use ``SQLStatement/raw(_:)``:
  ///
  /// ```swift
  /// let allUsers = try db.query(
  ///   SQLStatement.raw("SELECT name, age FROM users"),
  ///   stepper: { stmt, stop in
  ///     let name = try String.column(of: stmt, at: 0)
  ///     let age = try Int.column(of: stmt, at: 1)
  ///     return (name, age)
  ///   }
  /// )
  /// ```
  ///
  /// ## Benefits
  ///
  /// - **Type Safety**: Compile-time type checking for parameter values
  /// - **SQL Injection Prevention**: Automatic parameter binding prevents injection attacks
  /// - **Readability**: SQL reads naturally with interpolated values
  /// - **Reusability**: Statements can be constructed once and reused
  ///
  /// - Parameters:
  ///   - statement: The SQL query statement with its parameter bindings.
  ///   - stepper: A closure that extracts values from each result row.
  /// - Returns: An array of results, one element per row.
  /// - Throws: An error if query preparation, binding, execution, or extraction fails.
  @inline(__always)
  public func query<R>(
    _ statement: SQLStatement,
    stepper: Stepper<R>
  ) throws -> [R] {
    try query(raw: statement.sql, binder: statement.binder, stepper: stepper)
  }

  /// Executes a ``SQLStatement`` query with automatic column index management.
  ///
  /// This variant uses a ``ManagedStepper`` for automatic column index management,
  /// eliminating the need to manually track column indices during extraction.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let minAge = 18
  /// let users = try db.query(
  ///   "SELECT name, age, email FROM users WHERE age > \(minAge)",
  ///   stepper: { stmt, index, stop in
  ///     let name = try String.column(of: stmt, at: &index)  // Column 0
  ///     let age = try Int.column(of: stmt, at: &index)      // Column 1
  ///     let email = try String.column(of: stmt, at: &index) // Column 2
  ///     return (name, age, email)
  ///   }
  /// )
  /// ```
  ///
  /// ## Benefits
  ///
  /// Combines the benefits of ``SQLStatement`` (safe parameter binding through string
  /// interpolation) with automatic column index management for cleaner extraction code.
  ///
  /// - Parameters:
  ///   - statement: The SQL query statement with its parameter bindings.
  ///   - stepper: A closure that extracts values using automatic index management.
  /// - Returns: An array of results, one element per row.
  /// - Throws: An error if query preparation, binding, execution, or extraction fails.
  @inline(__always)
  public func query<R>(
    _ statement: SQLStatement,
    stepper: ManagedStepper<R>
  ) throws -> [R] {
    try query(raw: statement.sql, binder: statement.managedBinder, stepper: stepper)
  }
}
