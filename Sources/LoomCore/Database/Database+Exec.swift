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
  /// to completion. Suspends while a transaction owned by another task is active.
  ///
  /// Accepts exactly one statement — SQL containing a second one throws
  /// ``LoomCoreErrorCode/trailingSQL``. Use ``execScript(_:)`` for migration scripts.
  ///
  /// ```swift
  /// try await db.exec(
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
  ) async throws {
    try await gate()
    try execCore(raw: statement, binder: binder)
  }

  /// Ungated core shared by the public `exec` overloads and the transaction machinery
  /// (BEGIN/COMMIT/ROLLBACK/SAVEPOINT must not gate against their own transaction).
  /// Runs to completion synchronously on the actor, so once past the gate nothing can
  /// interleave mid-statement.
  func execCore(
    raw statement: String,
    binder: Binder
  ) throws {
    let stmt = try prepare(sql: statement)
    try binder(stmt)

    try check(sqlite3_step(stmt.stmtPtr), db: stmt.dbPtr, is: SQLITE_DONE)
  }

  func execCore(raw statement: String) throws {
    try execCore(raw: statement, binder: { _ in })
  }
}

extension Database {
  /// Executes a raw SQL statement with no parameters.
  ///
  /// ```swift
  /// try await db.exec(raw: "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
  /// try await db.exec(raw: "PRAGMA foreign_keys = ON")
  /// try await db.exec(raw: "DELETE FROM temp_data")
  /// ```
  ///
  /// For statements with dynamic values, use one of the binding overloads — never
  /// concatenate values into the SQL string, as that opens the door to SQL injection.
  /// For more than one statement, use ``execScript(_:)``.
  @inline(__always)
  public func exec(
    raw statement: String
  ) async throws {
    try await exec(raw: statement, binder: { _ in })
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
  /// try await db.exec(
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
  ) async throws {
    try await exec(
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
  /// try await db.exec(
  ///   raw: "INSERT INTO users (name, age, email) VALUES (?, ?, ?)",
  ///   binding: "Alice", 25, "alice@example.com"
  /// )
  ///
  /// try await db.exec(
  ///   raw: "UPDATE users SET age = ? WHERE name = ?",
  ///   binding: 26, "Alice"
  /// )
  /// ```
  @inline(__always)
  public func exec<each Values: Bindable>(
    raw statement: String,
    binding firstValue: some Bindable,
    _ otherValues: repeat each Values
  ) async throws {
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
    try await exec(
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
  /// try await db.exec("INSERT INTO users (name, age) VALUES (\(name), \(age))")
  /// ```
  ///
  /// For static SQL with no interpolated values, use ``SQLStatement/raw(_:)``:
  ///
  /// ```swift
  /// try await db.exec(SQLStatement.raw("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)"))
  /// ```
  @inline(__always)
  public func exec(
    _ statement: SQLStatement
  ) async throws {
    try await exec(raw: statement.sql, binder: statement.binder)
  }
}

// MARK: - Multi-Statement Scripts

extension Database {
  /// Executes every statement in a multi-statement SQL script, in order.
  ///
  /// The `exec` and `query` families prepare exactly one statement and throw
  /// ``LoomCoreErrorCode/trailingSQL`` when handed more. Use this for migration and schema
  /// scripts:
  ///
  /// ```swift
  /// try await db.execScript(
  ///   """
  ///   CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);
  ///   CREATE UNIQUE INDEX idx_users_name ON users (name);
  ///   """
  /// )
  /// ```
  ///
  /// Statements take no bound parameters (a `?` or named placeholder throws
  /// ``LoomCoreErrorCode/invalidScript``) and are never cached. Rows produced by a statement
  /// are stepped through and discarded. A failure part-way leaves earlier statements applied —
  /// wrap the call in ``Database/transaction(kind:_:)`` for all-or-nothing application.
  ///
  /// A script may manage its own transaction as long as it is balanced — `BEGIN … COMMIT`
  /// pairs (what `sqlite3 .dump` emits) run atomically because the whole script executes
  /// synchronously while holding the gate. A script that *leaves* a transaction open is
  /// rolled back and throws ``LoomCoreErrorCode/invalidScript``: the gate is released when
  /// this call returns, so an open transaction would swallow other tasks' writes with
  /// nothing left to commit them. Inside ``Database/transaction(kind:_:)``, a script
  /// statement that ends the enclosing transaction throws the same error. A script-managed
  /// transaction fires no ``Database/Service`` lifecycle hooks — when registered services
  /// must observe the commit, run the script inside ``Database/transaction(kind:_:)``
  /// instead.
  ///
  /// - Warning: Never build a script from user input — it bypasses parameter binding entirely.
  /// - Parameter script: One or more SQL statements separated by `;`.
  public func execScript(_ script: String) async throws {
    try await gate()
    try execScriptCore(script)
  }

  /// Ungated core of ``execScript(_:)``. Runs to completion synchronously on the actor,
  /// so once past the gate nothing can interleave between the script's statements.
  func execScriptCore(_ script: String) throws {
    let dbPtr = try handle.ptr

    // SQLite's prepare stops at the first zero byte no matter what length is passed, so a
    // NUL-contaminated script (a corrupt or binary-polluted file) can only ever half-apply.
    guard !script.utf8.contains(0) else {
      throw LoomError.core(
        .invalidScript,
        message: "Script contains an embedded NUL byte; statements after it would be silently dropped."
      )
    }

    let wasAutocommit = sqlite3_get_autocommit(dbPtr) != 0

    do {
      try script.withCString { start in
        var cursor: UnsafePointer<CChar>? = start
        while let current = cursor, current.pointee != 0 {
          var ptr: OpaquePointer?
          var tail: UnsafePointer<CChar>?
          try check(sqlite3_prepare_v3(dbPtr, current, -1, 0, &ptr, &tail), db: dbPtr, is: SQLITE_OK)

          // A nil statement means SQLite consumed the rest as whitespace or comments.
          guard let ptr else { break }
          defer { sqlite3_finalize(ptr) }

          // An unbound placeholder would silently evaluate as NULL — reject it instead.
          guard sqlite3_bind_parameter_count(ptr) == 0 else {
            throw LoomError.core(
              .invalidScript,
              message:
                "Script statements cannot take bound parameters; an unbound placeholder would silently bind NULL."
            )
          }

          var code = sqlite3_step(ptr)
          while code == SQLITE_ROW {
            code = sqlite3_step(ptr)
          }
          try check(code, db: dbPtr, is: SQLITE_DONE)

          // A COMMIT/ROLLBACK that ends the enclosing `transaction()` leaves the machinery's
          // own COMMIT/ROLLBACK doomed — surface it at the statement that did it, before any
          // further statements run outside the transaction.
          if activeTransactionToken != nil, sqlite3_get_autocommit(dbPtr) != 0 {
            throw LoomError.core(
              .invalidScript,
              message:
                "Script statement ended the enclosing transaction. Scripts inside `transaction { }` must not contain COMMIT or ROLLBACK."
            )
          }

          cursor = tail
        }
      }
    } catch {
      rollBackOpenScriptTransaction(dbPtr, wasAutocommit: wasAutocommit)
      throw error
    }

    // A transaction the script opened and never closed would outlive the gate: later writes
    // from any task would land in it, and nothing is left to commit them. Balanced
    // BEGIN…COMMIT scripts pass — autocommit is back to its entry state here.
    if wasAutocommit, sqlite3_get_autocommit(dbPtr) == 0 {
      rollBackOpenScriptTransaction(dbPtr, wasAutocommit: wasAutocommit)
      throw LoomError.core(
        .invalidScript,
        message:
          "Script left a transaction open; its work was rolled back. Balance BEGIN with COMMIT or ROLLBACK, or run the script inside `transaction { }`."
      )
    }
  }

  /// Best-effort restoration of autocommit after a script opened a transaction it didn't close.
  /// Only acts when the connection was in autocommit at script entry — inside `transaction()`,
  /// recovery belongs to the transaction machinery.
  private func rollBackOpenScriptTransaction(_ dbPtr: OpaquePointer, wasAutocommit: Bool) {
    guard wasAutocommit, sqlite3_get_autocommit(dbPtr) == 0 else { return }
    if sqlite3_exec(dbPtr, "ROLLBACK", nil, nil, nil) != SQLITE_OK {
      warn("Failed to roll back a transaction left open by a script: \(String(cString: sqlite3_errmsg(dbPtr)))")
    }
  }
}
