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
  /// let users = try await db.query(
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
  /// let firstActive = try await db.query(
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
  ///
  /// Suspends while a transaction owned by another task is active. Once past the gate the
  /// whole query — bind, step, extract — runs synchronously on the actor, so no other
  /// database work can interleave mid-statement. Cancelling the task interrupts the
  /// statement mid-step and throws `CancellationError`.
  public func query<R>(
    raw statement: String,
    binder: Binder,
    stepper: Stepper<R>
  ) async throws -> [R] {
    try await gate()
    return try await withInterruptOnCancellation {
      try queryCore(raw: statement, binder: binder, stepper: stepper)
    }
  }

  /// Ungated core of the `query` family. Runs to completion synchronously on the actor.
  private func queryCore<R>(
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
  /// let counts = try await db.query(
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
  ) async throws -> [R] {
    try await query(
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
  /// let users = try await db.query(
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
  ) async throws -> [R] {
    try await query(
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
  /// let users = try await db.query(
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
  ) async throws -> [R] {
    try await query(raw: statement, binder: { _, _ in }, stepper: stepper)
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
  /// let users = try await db.query(
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
  ) async throws -> [R] {
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
    return try await query(
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
  /// let users = try await db.query(
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
  ) async throws -> [R] {
    try await query(raw: statement.sql, binder: statement.binder, stepper: stepper)
  }

  /// Executes a ``SQLStatement`` query, pairing its embedded bindings with a ``ManagedStepper``.
  ///
  /// ```swift
  /// let minAge = 18
  /// let users = try await db.query(
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
  ) async throws -> [R] {
    try await query(raw: statement.sql, binder: statement.managedBinder, stepper: stepper)
  }
}

// MARK: - Inferred Row Types

/// Number of columns the row type `type` reads.
///
/// A pack expansion has to mention the pack it expands, so the count comes from expanding a call
/// that names each element and discards it. Folds to a constant at every concrete instantiation.
@inline(__always)
private func columnArity<each Column: Bindable>(of type: (repeat each Column).Type) -> Int32 {
  var arity: Int32 = 0
  func countElement<T>(_ elementType: T.Type) {
    arity += 1
  }
  repeat countElement((each Column).self)
  return arity
}

extension Database {
  /// Shared core of the inferred-row `query` overloads.
  ///
  /// Checks the statement's column count against the row type's arity from inside the binder: the
  /// binder runs once, after `prepare` and before the first `sqlite3_step`, so the check costs
  /// nothing per row and still fires for an empty result set. Delegating to the gated
  /// `query(raw:binder:stepper:)` keeps transaction gating and cancellation behaviour identical to
  /// the stepper-based overloads.
  private func queryRows<each Column: Bindable>(
    raw statement: String,
    binder: Binder
  ) async throws -> [(repeat each Column)] {
    let arity = columnArity(of: (repeat each Column).self)
    return try await query(
      raw: statement,
      binder: { stmt in
        let count = sqlite3_column_count(stmt.stmtPtr)
        guard count == arity else {
          throw LoomError.core(
            .columnCountMismatch,
            message: "Row type has \(arity) element(s) but the statement returns \(count) column(s)."
          )
        }
        try binder(stmt)
      },
      stepper: { stmt, _ in
        var index = ManagedIndex()
        return (repeat try (each Column).column(of: stmt, at: &index))
      }
    )
  }

  /// Executes a ``SQLStatement`` query, decoding each row into a tuple inferred from the return type.
  ///
  /// The row shape comes from the contextual result type: annotate the destination and each element
  /// is read left to right starting at column 0, with no `stepper` closure to write. Every element
  /// must conform to ``Bindable``; nullable columns use `Optional`.
  ///
  /// ```swift
  /// let users: [(String, Int, Date)] = try await db.query(
  ///   "SELECT name, age, created_at FROM users WHERE age >= \(18)"
  /// )
  /// ```
  ///
  /// A single-element row type reads one column and yields the value itself rather than a
  /// one-element tuple:
  ///
  /// ```swift
  /// let names: [String] = try await db.query("SELECT name FROM users ORDER BY name")
  /// ```
  ///
  /// The row type must have exactly as many elements as the statement returns columns, so a
  /// `SELECT` that grows a column fails loudly instead of decoding a shifted or absent one. That
  /// also rules out `[Void]` and any statement returning no columns at all. Column indices are
  /// 0-based; see <doc:IndexConventions>.
  ///
  /// These overloads always read the whole result set. Reach for the `stepper:` overloads when
  /// iteration has to end early or a row needs decoding these can't express.
  ///
  /// - Throws: ``LoomCoreErrorCode/columnCountMismatch`` when the row type's element count differs
  ///   from the statement's column count — checked before the first row is stepped, so it fires
  ///   even for an empty result set. ``LoomCoreErrorCode/nullValue`` when `NULL` lands in a
  ///   non-optional element, and ``LoomCoreErrorCode/typeMappingFailed`` when a stored value's
  ///   storage class can't be coerced to its element type.
  @inline(__always)
  public func query<each Column: Bindable>(
    _ statement: SQLStatement
  ) async throws -> [(repeat each Column)] {
    try await queryRows(raw: statement.sql, binder: statement.binder)
  }

  /// Executes a parameter-free raw SQL query, decoding each row into a tuple inferred from the return type.
  ///
  /// ```swift
  /// let counts: [(String, Int)] = try await db.query(
  ///   raw: "SELECT status, COUNT(*) FROM orders GROUP BY status"
  /// )
  /// ```
  ///
  /// For queries with dynamic values, prefer the ``SQLStatement`` overload — interpolating values
  /// into the SQL string opens the door to SQL injection.
  ///
  /// - Throws: ``LoomCoreErrorCode/columnCountMismatch`` when the row type's element count differs
  ///   from the statement's column count.
  @inline(__always)
  public func query<each Column: Bindable>(
    raw statement: String
  ) async throws -> [(repeat each Column)] {
    try await queryRows(raw: statement, binder: { _ in })
  }
}
