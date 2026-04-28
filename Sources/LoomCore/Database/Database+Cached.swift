/// Database methods for optimizing performance through prepared statement caching.
///
/// This file provides the `cached` method for enabling statement caching within a specific
/// execution scope, improving performance when executing the same SQL statements repeatedly.

extension Database {
  /// Executes a block of code with prepared statement caching enabled.
  ///
  /// Statement caching dramatically improves performance by reusing prepared statements instead
  /// of repreparing them on each execution. When a SQL statement is prepared for the first time
  /// within a `cached` block, it's stored in a cache. Subsequent executions of the same SQL
  /// reuse the cached prepared statement.
  ///
  /// ## When to Use
  ///
  /// Use statement caching when:
  /// - Executing the same SQL statement multiple times with different parameters
  /// - Performing batch operations (multiple inserts, updates, etc.)
  /// - Running queries in a loop
  /// - Optimizing performance-critical code paths
  ///
  /// ## Performance Benefits
  ///
  /// Preparing SQL statements involves parsing and optimizing the SQL, which has overhead.
  /// Caching eliminates this overhead for repeated executions:
  ///
  /// ```swift
  /// // Without caching - prepares the statement 1000 times
  /// for i in 0..<1000 {
  ///   try db.exec("INSERT INTO logs (message) VALUES (?)", binding: "Log \(i)")
  /// }
  ///
  /// // With caching - prepares the statement once, reuses it 1000 times
  /// try db.cached {
  ///   for i in 0..<1000 {
  ///     try db.exec("INSERT INTO logs (message) VALUES (?)", binding: "Log \(i)")
  ///   }
  /// }
  /// ```
  ///
  /// ## Scope and Lifetime
  ///
  /// Cached statements are only available within the `cached` block. Different blocks
  /// maintain separate caches:
  ///
  /// ```swift
  /// // First cached block
  /// try db.cached {
  ///   // Caches the statement
  ///   try db.exec("INSERT INTO users (name) VALUES (?)", binding: "Alice")
  ///   // Reuses the cached statement
  ///   try db.exec("INSERT INTO users (name) VALUES (?)", binding: "Bob")
  /// }
  /// // Cache is not cleared after the block exits
  ///
  /// // Second cached block
  /// try db.cached {
  ///   // Reuses the cached statement from the previous block
  ///   try db.exec("INSERT INTO users (name) VALUES (?)", binding: "Carol")
  /// }
  ///
  /// // Outside cached blocks - no caching
  /// try db.exec("INSERT INTO users (name) VALUES (?)", binding: "Dave")
  /// ```
  ///
  /// ## Nested Caching
  ///
  /// Nested `cached` blocks share the same cache, so caching is only activated once:
  ///
  /// ```swift
  /// try db.cached {
  ///   // Outer cache enabled
  ///   try db.exec("INSERT INTO users (name) VALUES (?)", binding: "Alice")
  ///
  ///   try db.cached {
  ///     // Still using the same cache (not creating a new one)
  ///     try db.exec("INSERT INTO users (name) VALUES (?)", binding: "Bob")
  ///   }
  /// }
  /// ```
  ///
  /// ## Query Example
  ///
  /// Caching works with both `exec` and `query` methods:
  ///
  /// ```swift
  /// let names = try db.cached {
  ///   try db.query("SELECT name FROM users") { stmt, index, _ in
  ///     try String.column(of: stmt, at: &index)
  ///   }
  /// }
  /// ```
  ///
  /// ## Implementation Note
  ///
  /// The method works by setting a persistent flag on the database options for the duration
  /// of the block. This flag instructs the database to cache prepared statements rather than
  /// immediately finalizing them after use.
  ///
  /// - Parameter block: The block of code to execute with statement caching enabled.
  /// - Returns: The result of the `block` closure.
  public func cached<T>(_ block: @DatabaseActor () throws -> T) rethrows -> T {
    if options.contains(.persistent) {
      return try block()
    }

    options.insert(.persistent)
    defer { options.remove(.persistent) }
    return try block()
  }
}
