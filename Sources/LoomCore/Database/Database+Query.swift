/// Database methods for executing SQL queries that return rows.
///
/// For statements that don't return rows (INSERT, UPDATE, DELETE), use the `exec` family.

import SQLite3

// MARK: - Raw Statement Queries

extension Database {
  /// Executes a raw SQL query, binding parameters and extracting each row through closures.
  ///
  /// Prepares `statement`, invokes `binder` once to bind parameters, then calls `stepper`
  /// for every result row. Returned values are collected into an array.
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
  /// ```
  ///
  /// Set `stop` to `true` inside `stepper` to halt iteration after the current row:
  ///
  /// ```swift
  /// let firstActive = try db.query(
  ///   raw: "SELECT id, name FROM users WHERE active = 1 ORDER BY id",
  ///   binder: { _ in },
  ///   stepper: { stmt, stop in
  ///     stop = true
  ///     return try (Int.column(of: stmt, at: 0), String.column(of: stmt, at: 1))
  ///   }
  /// ).first
  /// ```
  ///
  /// Parameter indices are 1-based; column indices are 0-based. See <doc:IndexConventions>.
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
  /// Executes a parameter-free raw SQL query and extracts each row through `stepper`.
  ///
  /// ```swift
  /// let counts = try db.query(
  ///   raw: "SELECT status, COUNT(*) FROM orders GROUP BY status",
  ///   stepper: { stmt, _ in
  ///     let status = try String.column(of: stmt, at: 0)
  ///     let count = try Int.column(of: stmt, at: 1)
  ///     return (status, count)
  ///   }
  /// )
  /// ```
  ///
  /// For queries with dynamic values, prefer the ``SQLStatement``-based overloads
  /// or `binding:` variant — interpolating values into the SQL string opens the door
  /// to SQL injection.
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
  /// Executes a raw SQL query using ``ManagedIndex``-backed binder and stepper closures.
  ///
  /// Both closures receive a `ManagedIndex` that auto-advances on each bind or column
  /// read, removing the need to track positions by hand and making it safe to add or
  /// remove parameters and columns without renumbering.
  ///
  /// ```swift
  /// let users = try db.query(
  ///   raw: "SELECT name, age, email FROM users WHERE age > ? AND status = ?",
  ///   binder: { stmt, index in
  ///     try 18.bind(to: stmt, at: &index)
  ///     try "active".bind(to: stmt, at: &index)
  ///   },
  ///   stepper: { stmt, index, _ in
  ///     let name = try String.column(of: stmt, at: &index)
  ///     let age = try Int.column(of: stmt, at: &index)
  ///     let email = try String.column(of: stmt, at: &index)
  ///     return (name, age, email)
  ///   }
  /// )
  /// ```
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

  /// Executes a parameter-free raw SQL query using a ``ManagedStepper`` for column extraction.
  ///
  /// ```swift
  /// let users = try db.query(
  ///   raw: "SELECT name, age, email FROM users",
  ///   stepper: { stmt, index, _ in
  ///     let name = try String.column(of: stmt, at: &index)
  ///     let age = try Int.column(of: stmt, at: &index)
  ///     let email = try String.column(of: stmt, at: &index)
  ///     return (name, age, email)
  ///   }
  /// )
  /// ```
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
  /// Executes a raw SQL query with parameters supplied inline as variadic ``Bindable`` values.
  ///
  /// Values are bound left-to-right in the order given. Column extraction uses a
  /// ``ManagedStepper``.
  ///
  /// ```swift
  /// let users = try db.query(
  ///   raw: "SELECT name, age FROM users WHERE age > ? AND status = ?",
  ///   binding: 18, "active",
  ///   stepper: { stmt, index, _ in
  ///     let name = try String.column(of: stmt, at: &index)
  ///     let age = try Int.column(of: stmt, at: &index)
  ///     return (name, age)
  ///   }
  /// )
  /// ```
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
  /// Executes a ``SQLStatement`` query, using its embedded bindings and a `Stepper` for extraction.
  ///
  /// Prefer this overload for everyday querying: string interpolation produces safely
  /// bound parameters with no manual binder closure.
  ///
  /// ```swift
  /// let minAge = 18
  /// let status = "active"
  /// let users = try db.query(
  ///   "SELECT name, age FROM users WHERE age > \(minAge) AND status = \(status)",
  ///   stepper: { stmt, _ in
  ///     let name = try String.column(of: stmt, at: 0)
  ///     let age = try Int.column(of: stmt, at: 1)
  ///     return (name, age)
  ///   }
  /// )
  /// ```
  ///
  /// For queries without parameters, build the statement with ``SQLStatement/raw(_:)``.
  @inline(__always)
  public func query<R>(
    _ statement: SQLStatement,
    stepper: Stepper<R>
  ) throws -> [R] {
    try query(raw: statement.sql, binder: statement.binder, stepper: stepper)
  }

  /// Executes a ``SQLStatement`` query, pairing its embedded bindings with a ``ManagedStepper``.
  ///
  /// ```swift
  /// let minAge = 18
  /// let users = try db.query(
  ///   "SELECT name, age, email FROM users WHERE age > \(minAge)",
  ///   stepper: { stmt, index, _ in
  ///     let name = try String.column(of: stmt, at: &index)
  ///     let age = try Int.column(of: stmt, at: &index)
  ///     let email = try String.column(of: stmt, at: &index)
  ///     return (name, age, email)
  ///   }
  /// )
  /// ```
  @inline(__always)
  public func query<R>(
    _ statement: SQLStatement,
    stepper: ManagedStepper<R>
  ) throws -> [R] {
    try query(raw: statement.sql, binder: statement.managedBinder, stepper: stepper)
  }
}
