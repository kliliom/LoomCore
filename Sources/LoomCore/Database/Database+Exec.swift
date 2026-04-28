/// Database methods for executing SQL statements that don't return results.
///
/// Provides `exec` overloads for executing INSERT, UPDATE, DELETE, and DDL statements
/// (CREATE TABLE, etc.). For queries that return rows, use the query methods instead.

import SQLite3

// MARK: - Raw Statement Execution

extension Database {
  /// Executes a raw SQL statement with a custom parameter binder.
  ///
  /// Suitable for INSERT, UPDATE, DELETE, DDL (CREATE/DROP/ALTER), PRAGMA, and any other
  /// non-SELECT statement. The statement is prepared, bound via the closure, then stepped
  /// to completion.
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
  /// Parameter indices in the binder are 1-based, matching SQLite's convention.
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
  /// Executes a raw SQL statement with no parameters.
  ///
  /// ```swift
  /// try db.exec(raw: "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
  /// try db.exec(raw: "PRAGMA foreign_keys = ON")
  /// try db.exec(raw: "DELETE FROM temp_data")
  /// ```
  ///
  /// For statements with dynamic values, use one of the binding overloads — never
  /// concatenate values into the SQL string, as that opens the door to SQL injection.
  @inline(__always)
  public func exec(
    raw statement: String
  ) throws {
    try exec(raw: statement, binder: { _ in })
  }
}

// MARK: - Managed Binder Convenience

extension Database {
  /// Executes a raw SQL statement using a ``ManagedBinder`` for automatic index management.
  ///
  /// The index is incremented before each bind, so the first `bind(to:at:)` call writes to
  /// parameter 1, the second to parameter 2, and so on.
  ///
  /// ```swift
  /// try db.exec(
  ///   raw: "INSERT INTO users (name, age, email) VALUES (?, ?, ?)",
  ///   binder: { stmt, index in
  ///     try "Alice".bind(to: stmt, at: &index)
  ///     try 25.bind(to: stmt, at: &index)
  ///     try "alice@example.com".bind(to: stmt, at: &index)
  ///   }
  /// )
  /// ```
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
  /// Executes a raw SQL statement with positional parameter values.
  ///
  /// Values are bound to `?` placeholders in argument order. Each value must conform to
  /// ``Bindable``, which the compiler enforces.
  ///
  /// ```swift
  /// try db.exec(
  ///   raw: "INSERT INTO users (name, age, email) VALUES (?, ?, ?)",
  ///   binding: "Alice", 25, "alice@example.com"
  /// )
  ///
  /// try db.exec(
  ///   raw: "UPDATE users SET age = ? WHERE name = ?",
  ///   binding: 26, "Alice"
  /// )
  /// ```
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
  /// Executes a ``SQLStatement`` built via string interpolation.
  ///
  /// Interpolated values become `?` placeholders bound through ``Bindable``, so the
  /// statement is type-safe and immune to SQL injection.
  ///
  /// ```swift
  /// let name = "Alice"
  /// let age = 25
  /// try db.exec("INSERT INTO users (name, age) VALUES (\(name), \(age))")
  /// ```
  ///
  /// For static SQL with no interpolated values, use ``SQLStatement/raw(_:)``:
  ///
  /// ```swift
  /// try db.exec(SQLStatement.raw("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)"))
  /// ```
  @inline(__always)
  public func exec(
    _ statement: SQLStatement
  ) throws {
    try exec(raw: statement.sql, binder: statement.binder)
  }
}
