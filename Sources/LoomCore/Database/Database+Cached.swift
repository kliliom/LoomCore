extension Database {
  /// Enables prepared statement caching for the duration of `block`.
  ///
  /// SQLite parses and optimizes SQL on first preparation. Inside a `cached` block, statements
  /// prepared for the first time are retained in the database's statement cache and reused on
  /// subsequent calls with the same SQL — turning per-call preparation into a one-time cost
  /// for tight loops and batch operations.
  ///
  /// ```swift
  /// try db.cached {
  ///   for entry in pendingLogs {
  ///     try db.exec(
  ///       "INSERT INTO logs (message, level) VALUES (?, ?)",
  ///       binding: entry.message, entry.level
  ///     )
  ///   }
  /// }
  /// ```
  ///
  /// Caching applies to both `exec` and `query`:
  ///
  /// ```swift
  /// let names = try db.cached {
  ///   try db.query("SELECT name FROM users WHERE active = 1") { stmt, index, _ in
  ///     try String.column(of: stmt, at: &index)
  ///   }
  /// }
  /// ```
  ///
  /// ## Lifetime
  ///
  /// Cached statements are not finalized when the block exits — the cache lives on the
  /// `Database` and grows unbounded as new SQL strings are seen, so a second `cached` block
  /// reuses statements prepared by the first. Nested `cached` calls share the existing scope
  /// and do not enable caching twice.
  public func cached<T>(_ block: @DatabaseActor () throws -> T) rethrows -> T {
    if options.contains(.persistent) {
      return try block()
    }

    options.insert(.persistent)
    defer { options.remove(.persistent) }
    return try block()
  }
}
