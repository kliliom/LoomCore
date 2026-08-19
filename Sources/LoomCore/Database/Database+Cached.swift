/// Statement-caching scope, tracked per task tree and per database.
///
/// A task-local rather than database state: `cached` bodies can suspend, and a flag stored
/// on the `Database` would leak caching to unrelated tasks interleaving at those suspension
/// points. The set carries the identities of the databases that opted in, so operations on
/// a *different* database inside a `cached` block do not populate that database's cache.
enum StatementCaching {
  @TaskLocal static var databases: Set<ObjectIdentifier> = []
}

extension Database {
  /// Enables prepared statement caching for the duration of `block`.
  ///
  /// SQLite parses and optimizes SQL on first preparation. Inside a `cached` block, statements
  /// prepared for the first time are retained in the database's statement cache and reused on
  /// subsequent calls with the same SQL — turning per-call preparation into a one-time cost
  /// for tight loops and batch operations.
  ///
  /// ```swift
  /// let pendingLogs = [(message: "started", level: 1), (message: "finished", level: 2)]
  /// try await db.cached {
  ///   for entry in pendingLogs {
  ///     try await db.exec(
  ///       raw: "INSERT INTO logs (message, level) VALUES (?, ?)",
  ///       binding: entry.message, entry.level
  ///     )
  ///   }
  /// }
  /// ```
  ///
  /// Caching applies to both `exec` and `query`:
  ///
  /// ```swift
  /// let names = try await db.cached {
  ///   try await db.query("SELECT name FROM users WHERE active = 1") { stmt, index, _ in
  ///     try String.column(of: stmt, at: &index)
  ///   }
  /// }
  /// ```
  ///
  /// Caching is scoped to the current task tree, so concurrent tasks running database work
  /// outside the block are unaffected.
  ///
  /// ## Lifetime
  ///
  /// Cached statements are not finalized when the block exits — the cache lives on the
  /// `Database`, so a second `cached` block reuses statements prepared by the first. It is
  /// bounded by the `statementCacheCapacity` set at ``open(url:statementCacheCapacity:)``
  /// (128 by default): at capacity, the least-recently-used statement is finalized to make
  /// room, so hot-loop statements stay resident while one-off SQL cycles out. Call
  /// ``clearStatementCache()`` to release the cache eagerly. Nested `cached` calls share
  /// the existing scope and do not enable caching twice.
  public func cached<T>(_ block: @DatabaseActor () async throws -> T) async rethrows -> T {
    let id = ObjectIdentifier(self)
    if StatementCaching.databases.contains(id) {
      return try await block()
    }

    return try await StatementCaching.$databases.withValue(StatementCaching.databases.union([id])) {
      try await block()
    }
  }
}
