/// Convenience methods for accessing SQLite PRAGMA statements.
///
/// Provides type-safe, high-level access to commonly used SQLite PRAGMA statements for
/// configuring database behavior, querying metadata, and performing maintenance operations.
///
/// ## PRAGMA Categories
///
/// - **Configuration**: journal mode, synchronous, cache size, foreign keys, etc.
/// - **Maintenance**: optimize, vacuum, integrity check.
/// - **Introspection**: table info, indexes, foreign keys.
///
/// ## Thread Safety
///
/// All PRAGMA methods are isolated to ``DatabaseActor``, ensuring thread-safe access to the
/// database configuration.

import Foundation
import SQLite3

// MARK: - Journal Mode

extension Database {
  /// Journal mode controlling how the rollback journal is managed.
  ///
  /// Affects durability, performance, and concurrency characteristics.
  public enum JournalMode: String, Sendable, CaseIterable {
    /// Deletes the journal file after each transaction (default).
    ///
    /// Traditional SQLite behavior. Good balance of safety and performance for single-connection use.
    case delete = "DELETE"

    /// Truncates the journal file to zero length instead of deleting it.
    ///
    /// Slightly faster than `.delete` on some systems by avoiding directory changes.
    case truncate = "TRUNCATE"

    /// Keeps the journal file but overwrites the header with zeros.
    ///
    /// Avoids the overhead of deleting and recreating the journal file.
    case persist = "PERSIST"

    /// Keeps the journal in memory rather than on disk.
    ///
    /// Fastest mode but loses rollback capability if the process crashes. Not recommended for production use.
    case memory = "MEMORY"

    /// Writes changes to a separate WAL file (Write-Ahead Logging).
    ///
    /// Significantly better concurrency since readers don't block writers. Recommended for most production
    /// applications.
    case wal = "WAL"

    /// Disables the rollback journal entirely.
    ///
    /// Disables rollback and atomic commit. Database may become corrupted if a crash occurs mid-transaction.
    /// Only use for temporary databases.
    case off = "OFF"
  }

  /// Returns the current journal mode.
  ///
  /// ```swift
  /// let mode = try await db.getJournalMode()
  /// if mode != .wal {
  ///   try await db.setJournalMode(.wal)
  /// }
  /// ```
  public func getJournalMode() async throws -> JournalMode {
    let result = try await query("PRAGMA journal_mode") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    guard let modeString = result.first,
      let mode = JournalMode(rawValue: modeString.uppercased())
    else {
      throw LoomError.core(.unexpectedState, message: "Invalid journal_mode value")
    }

    return mode
  }

  /// Sets the journal mode and returns the mode actually applied.
  ///
  /// Some changes may not take effect — for example, switching to `.wal` fails on a network filesystem
  /// that doesn't support shared memory. Inspect the returned value to confirm.
  ///
  /// ```swift
  /// let active = try await db.setJournalMode(.wal)
  /// precondition(active == .wal, "WAL mode unavailable on this filesystem")
  /// ```
  @discardableResult
  public func setJournalMode(_ mode: JournalMode) async throws -> JournalMode {
    let result = try await query("PRAGMA journal_mode = \(mode.rawValue, mode: .raw)") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    guard let modeString = result.first,
      let resultMode = JournalMode(rawValue: modeString.uppercased())
    else {
      throw LoomError.core(.unexpectedState, message: "Invalid journal_mode result")
    }

    return resultMode
  }
}

// MARK: - Synchronous Mode

extension Database {
  /// Synchronous mode controlling how aggressively SQLite syncs to disk.
  ///
  /// Trades durability against write performance.
  public enum SynchronousMode: Int32, Sendable, CaseIterable {
    /// Skips syncing entirely (fastest, most dangerous).
    ///
    /// SQLite does not pause to wait for data to reach disk. Database may become corrupted if the OS crashes
    /// or loses power. Only use for temporary data.
    case off = 0

    /// Syncs at the most critical moments.
    ///
    /// Safe with WAL mode but can corrupt the database in rollback journal modes if the OS crashes at the
    /// wrong time. Good balance for WAL mode.
    case normal = 1

    /// Syncs after every transaction (default).
    ///
    /// Ensures data reaches disk before transactions commit. Safest standard option but slower. Recommended
    /// for important data in `.delete`/`.truncate`/`.persist` journal modes.
    case full = 2

    /// Goes beyond `.full` for maximum safety.
    ///
    /// Reduces risk of corruption in extremely rare scenarios. Significantly slower than `.full` with minimal
    /// additional safety benefit.
    case extra = 3
  }

  /// Returns the current synchronous mode.
  public func getSynchronous() async throws -> SynchronousMode {
    let result = try await query("PRAGMA synchronous") { stmt, _ in
      try Int32.column(of: stmt, at: 0)
    }

    guard let value = result.first,
      let mode = SynchronousMode(rawValue: value)
    else {
      throw LoomError.core(.unexpectedState, message: "Invalid synchronous value")
    }

    return mode
  }

  /// Sets the synchronous mode.
  ///
  /// ## Recommended Settings
  ///
  /// - WAL mode: `.normal` — good balance of safety and performance.
  /// - DELETE/TRUNCATE/PERSIST modes: `.full` — full durability.
  /// - Temporary data only: `.off` — maximum speed, no crash safety.
  ///
  /// ```swift
  /// try await db.setJournalMode(.wal)
  /// try await db.setSynchronous(.normal)
  /// ```
  public func setSynchronous(_ mode: SynchronousMode) async throws {
    try await exec("PRAGMA synchronous = \(mode.rawValue, mode: .raw)")
  }
}

// MARK: - Cache Size

extension Database {
  /// Cache size controlling the amount of memory SQLite uses for caching database pages.
  public enum CacheSize: Sendable, Hashable {
    /// Cache size specified in pages.
    case pages(Int32)
    /// Cache size specified in kibibytes.
    case kibibytes(Int32)

    /// Creates a `CacheSize` from a raw `Int32` value as returned by SQLite.
    ///
    /// Negative values map to ``kibibytes(_:)``; positive values map to ``pages(_:)``.
    public init(raw: Int32) {
      if raw < 0 {
        self = .kibibytes(-raw)
      } else {
        self = .pages(raw)
      }
    }
  }

  /// Returns the suggested maximum number of database pages held in memory.
  ///
  /// Pages are typically 4096 bytes each. A negative raw value means the cache size is specified in
  /// kibibytes — ``CacheSize`` normalizes that for you.
  public func getCacheSize() async throws -> CacheSize {
    let result = try await query("PRAGMA cache_size") { stmt, _ in
      try Int32.column(of: stmt, at: 0)
    }

    guard let size = result.first else {
      throw LoomError.core(.unexpectedState, message: "cache_size returned no value")
    }

    return CacheSize(raw: size)
  }

  /// Sets the suggested maximum number of database pages held in memory.
  ///
  /// Larger cache sizes improve performance for read-heavy workloads at the cost of memory. The default is
  /// usually `-2000` (2 MiB).
  ///
  /// ```swift
  /// // Cap the cache at 10 MiB.
  /// try await db.setCacheSize(.kibibytes(10240))
  ///
  /// // Or 2560 pages (~10 MiB at 4 KiB pages).
  /// try await db.setCacheSize(.pages(2560))
  /// ```
  public func setCacheSize(_ size: CacheSize) async throws {
    let rawValue: Int32
    switch size {
    case .pages(let pages):
      rawValue = pages
    case .kibibytes(let kibibytes):
      rawValue = -kibibytes
    }
    try await exec("PRAGMA cache_size = \(rawValue, mode: .raw)")
  }
}

// MARK: - Temp Store

extension Database {
  /// Location where temporary tables and indexes are stored.
  public enum TempStoreMode: Int32, Sendable, CaseIterable {
    /// Uses the compile-time default (usually `.file`).
    case `default` = 0

    /// Stores temporary tables in files on disk.
    ///
    /// Slower than memory-backed storage but doesn't consume process memory.
    case file = 1

    /// Stores temporary tables in memory.
    ///
    /// Faster but uses more memory. Recommended for most applications.
    case memory = 2
  }

  /// Returns the current `temp_store` mode.
  public func getTempStore() async throws -> TempStoreMode {
    let result = try await query("PRAGMA temp_store") { stmt, _ in
      try Int32.column(of: stmt, at: 0)
    }

    guard let value = result.first,
      let mode = TempStoreMode(rawValue: value)
    else {
      throw LoomError.core(.unexpectedState, message: "Invalid temp_store value")
    }

    return mode
  }

  /// Sets the `temp_store` mode.
  ///
  /// ```swift
  /// // Keep ephemeral B-trees in memory for hot query paths.
  /// try await db.setTempStore(.memory)
  /// ```
  public func setTempStore(_ mode: TempStoreMode) async throws {
    try await exec("PRAGMA temp_store = \(mode.rawValue, mode: .raw)")
  }
}

// MARK: - Memory-Mapped I/O

extension Database {
  /// Returns the maximum number of bytes available for memory-mapped I/O.
  ///
  /// A return value of `0` indicates memory-mapped I/O is disabled.
  public func getMmapSize() async throws -> Int64 {
    let result = try await query("PRAGMA mmap_size") { stmt, _ in
      try Int64.column(of: stmt, at: 0)
    }

    guard let size = result.first else {
      throw LoomError.core(.unexpectedState, message: "mmap_size returned no value")
    }

    return size
  }

  /// Sets the maximum number of bytes used for memory-mapped I/O and returns the value actually applied.
  ///
  /// Memory-mapped I/O can improve read performance by letting SQLite access pages directly without system
  /// calls. It may misbehave on some platforms or with very large databases — verify the returned size if
  /// you need to confirm the request succeeded.
  ///
  /// ```swift
  /// // Map up to 256 MiB of the database.
  /// _ = try await db.setMmapSize(256 * 1024 * 1024)
  ///
  /// // Disable memory-mapped I/O.
  /// _ = try await db.setMmapSize(0)
  /// ```
  ///
  /// - Parameter size: Maximum mmap size in bytes, or `0` to disable.
  @discardableResult
  public func setMmapSize(_ size: Int64) async throws -> Int64 {
    let result = try await query("PRAGMA mmap_size = \(size, mode: .raw)") { stmt, _ in
      try Int64.column(of: stmt, at: 0)
    }

    guard let size = result.first else {
      throw LoomError.core(.unexpectedState, message: "mmap_size returned no value")
    }

    return size
  }
}

// MARK: - Foreign Keys

extension Database {
  /// Returns whether foreign key constraint enforcement is enabled.
  ///
  /// Foreign keys are disabled by default for backwards compatibility with legacy databases.
  public func getForeignKeys() async throws -> Bool {
    let result = try await query("PRAGMA foreign_keys") { stmt, _ in
      try Int32.column(of: stmt, at: 0)
    }

    return result.first == 1
  }

  /// Enables or disables foreign key constraint enforcement.
  ///
  /// This setting can only be changed when no transaction is active — set it immediately after opening the
  /// database.
  ///
  /// ```swift
  /// let db = try await Database.openInMemory()
  /// try await db.setForeignKeys(true)
  /// ```
  public func setForeignKeys(_ enabled: Bool) async throws {
    try await exec("PRAGMA foreign_keys = \(enabled ? 1 : 0, mode: .raw)")
  }
}

// MARK: - Auto Vacuum

extension Database {
  /// Auto-vacuum mode controlling automatic database file size management.
  public enum AutoVacuumMode: Int32, Sendable, CaseIterable {
    /// Disables automatic vacuuming (default).
    ///
    /// Database file never shrinks. Use ``Database/vacuum()`` manually to reclaim space.
    case none = 0

    /// Reclaims freed space automatically after each transaction.
    ///
    /// Database file shrinks when data is deleted, at the cost of additional overhead on delete operations.
    case full = 1

    /// Marks freed pages for later manual reclamation.
    ///
    /// Free pages accumulate but aren't returned to the filesystem until ``Database/incrementalVacuum(pages:)``
    /// runs, giving you control over when reclamation work happens.
    case incremental = 2
  }

  /// Returns the current auto-vacuum mode.
  public func getAutoVacuum() async throws -> AutoVacuumMode {
    let result = try await query("PRAGMA auto_vacuum") { stmt, _ in
      try Int32.column(of: stmt, at: 0)
    }

    guard let value = result.first,
      let mode = AutoVacuumMode(rawValue: value)
    else {
      throw LoomError.core(.unexpectedState, message: "Invalid auto_vacuum value")
    }

    return mode
  }

  /// Sets the auto-vacuum mode.
  ///
  /// Changing this mode requires a subsequent `VACUUM` to take effect. It cannot be applied to attached
  /// databases or while a transaction is active.
  ///
  /// ```swift
  /// try await db.setAutoVacuum(.incremental)
  /// try await db.vacuum()  // required for the change to take effect
  /// ```
  public func setAutoVacuum(_ mode: AutoVacuumMode) async throws {
    try await exec("PRAGMA auto_vacuum = \(mode.rawValue, mode: .raw)")
  }
}

// MARK: - Maintenance Operations

extension Database {
  /// Runs a comprehensive integrity check on the database.
  ///
  /// Verifies that all B-tree pages are correctly structured and that all content can be read. Returns an
  /// empty array when the database is healthy.
  ///
  /// ```swift
  /// let issues = try await db.integrityCheck()
  /// if issues.isEmpty {
  ///   print("Database integrity OK")
  /// } else {
  ///   for issue in issues {
  ///     print("  - \(issue)")
  ///   }
  /// }
  /// ```
  ///
  /// - Parameter maxErrors: Maximum number of errors to return before stopping.
  /// - Returns: Error messages found, or an empty array if the database is healthy.
  public func integrityCheck(maxErrors: Int32 = 100) async throws -> [String] {
    let results = try await query("PRAGMA integrity_check(\(maxErrors, mode: .raw))") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    if results.count == 1 && results[0].lowercased() == "ok" {
      return []
    }

    return results
  }

  /// Asks SQLite to opportunistically optimize the database.
  ///
  /// Analyzes the database and may restructure internal data to improve query performance. Safe to run
  /// periodically — SQLite only acts when work would be beneficial.
  ///
  /// ```swift
  /// // Run during scheduled maintenance or at app shutdown.
  /// try await db.optimize()
  /// ```
  public func optimize() async throws {
    try await exec("PRAGMA optimize")
  }

  /// Performs a full `VACUUM` of the database.
  ///
  /// Rebuilds the database file, repacking it into a minimal amount of disk space. This:
  /// - reclaims freed space from deleted data,
  /// - defragments the database for better locality,
  /// - resets `AUTOINCREMENT` counters,
  /// - rebuilds indexes.
  ///
  /// Requires exclusive access and temporarily uses up to twice the database size on disk. Cannot run inside
  /// a transaction or against attached databases.
  ///
  /// ```swift
  /// try await db.exec("DELETE FROM old_logs WHERE created_at < ?", binding: cutoffDate)
  /// try await db.vacuum()
  /// ```
  ///
  /// ## Performance Considerations
  ///
  /// - `VACUUM` can take a long time on multi-gigabyte databases.
  /// - Prefer ``AutoVacuumMode/incremental`` with ``incrementalVacuum(pages:)`` for finer-grained control.
  /// - For WAL-mode databases, ``walCheckpoint(mode:schema:)`` may be the better tool.
  public func vacuum() async throws {
    try await exec("VACUUM")
  }

  /// Reclaims pages from the free list when in ``AutoVacuumMode/incremental`` mode.
  ///
  /// ```swift
  /// try await db.setAutoVacuum(.incremental)
  /// try await db.vacuum()  // apply the new mode
  ///
  /// // Later, in a maintenance window, reclaim freed pages a chunk at a time.
  /// try await db.incrementalVacuum(pages: 100)
  /// ```
  ///
  /// - Parameter pages: Maximum number of pages to remove. Pass `nil` to remove all free pages.
  public func incrementalVacuum(pages: Int32? = nil) async throws {
    let statement: SQLStatement =
      if let pages {
        "PRAGMA incremental_vacuum(\(pages, mode: .raw))"
      } else {
        "PRAGMA incremental_vacuum"
      }
    _ = try await query(statement) { stmt, _ in }
  }
}

// MARK: - WAL Checkpoint

extension Database {
  /// WAL checkpoint mode determining how aggressively to checkpoint.
  public enum WALCheckpointMode: String, Sendable, CaseIterable {
    /// Checkpoints as much as possible without blocking.
    ///
    /// Doesn't wait for readers or writers — checkpoints whatever is immediately available. Recommended for
    /// background checkpointing.
    case passive = "PASSIVE"

    /// Blocks until all pages are checkpointed.
    ///
    /// Waits for active readers to finish, then checkpoints the entire WAL. May block for some time under
    /// concurrent read load.
    case full = "FULL"

    /// Performs a full checkpoint then restarts the WAL.
    ///
    /// Like `.full`, but additionally resets the WAL file to the beginning.
    case restart = "RESTART"

    /// Performs a full checkpoint then truncates the WAL to zero bytes.
    ///
    /// Most aggressive option — guarantees the WAL file is emptied.
    case truncate = "TRUNCATE"
  }

  /// Result of a WAL checkpoint operation.
  public struct WALCheckpointInfo: Sendable {
    /// Whether the checkpoint was unable to complete due to busy readers/writers.
    public let busy: Bool

    /// Number of modified pages in the WAL before the checkpoint.
    public let logPages: Int32

    /// Number of pages successfully checkpointed.
    public let checkpointedPages: Int32
  }

  /// Performs a WAL checkpoint, transferring pages from the WAL back into the main database file.
  ///
  /// Only meaningful when the database is in ``JournalMode/wal`` mode.
  ///
  /// ```swift
  /// try await db.setJournalMode(.wal)
  ///
  /// let info = try await db.walCheckpoint(mode: .passive)
  /// print("Checkpointed \(info.checkpointedPages) of \(info.logPages) pages")
  /// ```
  ///
  /// - Parameters:
  ///   - mode: Checkpoint mode controlling blocking behavior and WAL truncation.
  ///   - schema: Schema name to checkpoint (e.g. `"main"`, `"temp"`, or an attached database name).
  public func walCheckpoint(
    mode: WALCheckpointMode = .passive,
    schema: String = "main"
  ) async throws -> WALCheckpointInfo {
    let results = try await query(
      "PRAGMA \(schema, mode: .raw).wal_checkpoint(\(mode.rawValue, mode: .raw))"
    ) { stmt, _ in
      (
        busy: try Int32.column(of: stmt, at: 0),
        log: try Int32.column(of: stmt, at: 1),
        checkpointed: try Int32.column(of: stmt, at: 2)
      )
    }

    guard let result = results.first else {
      throw LoomError.core(.unexpectedState, message: "wal_checkpoint returned no results")
    }

    return WALCheckpointInfo(
      busy: result.busy != 0,
      logPages: result.log,
      checkpointedPages: result.checkpointed
    )
  }
}

// MARK: - Schema Introspection

extension Database {
  /// Information about a single column in a table.
  public struct ColumnInfo: Sendable {
    /// Column index (0-based).
    public let cid: Int32

    /// Column name.
    public let name: String

    /// Declared column type (e.g. `"INTEGER"`, `"TEXT"`, `"REAL"`, `"BLOB"`).
    public let type: String

    /// Whether the column has a `NOT NULL` constraint.
    public let notNull: Bool

    /// Default value expression for the column, if any.
    public let defaultValue: String?

    /// Position within the primary key (1-based), or `0` if not part of the primary key.
    public let pk: Int32
  }

  /// Returns the column metadata for a table.
  ///
  /// ```swift
  /// for column in try await db.tableInfo("users") {
  ///   let nullability = column.notNull ? " NOT NULL" : ""
  ///   print("\(column.name): \(column.type)\(nullability)")
  /// }
  /// ```
  public func tableInfo(_ tableName: String) async throws -> [ColumnInfo] {
    try await query("PRAGMA table_info(\(tableName, mode: .raw))") { stmt, _ in
      ColumnInfo(
        cid: try Int32.column(of: stmt, at: 0),
        name: try String.column(of: stmt, at: 1),
        type: try String.column(of: stmt, at: 2),
        notNull: try Int32.column(of: stmt, at: 3) != 0,
        defaultValue: try String?.column(of: stmt, at: 4),
        pk: try Int32.column(of: stmt, at: 5)
      )
    }
  }

  /// Information about a table or view in the database.
  public struct TableInfo: Sendable {
    /// Schema containing the table (e.g. `"main"`, `"temp"`).
    public let schema: String

    /// Table name.
    public let name: String

    /// Object type — typically `"table"` or `"view"`.
    public let type: String

    /// Number of columns in the table.
    public let ncol: Int32

    /// Whether this is a `WITHOUT ROWID` table.
    public let withoutRowid: Bool

    /// Whether this is a `STRICT` table (column types are enforced).
    public let strict: Bool
  }

  /// Lists all tables and views in a schema.
  ///
  /// ```swift
  /// for table in try await db.tableList() where table.type == "table" {
  ///   print("\(table.name): \(table.ncol) columns")
  /// }
  /// ```
  ///
  /// - Parameter schema: Schema to list tables from (e.g. `"main"`, `"temp"`, or an attached database name).
  public func tableList(schema: String = "main") async throws -> [TableInfo] {
    try await query("PRAGMA \(schema, mode: .raw).table_list") { stmt, _ in
      TableInfo(
        schema: try String.column(of: stmt, at: 0),
        name: try String.column(of: stmt, at: 1),
        type: try String.column(of: stmt, at: 2),
        ncol: try Int32.column(of: stmt, at: 3),
        withoutRowid: try Int32.column(of: stmt, at: 4) != 0,
        strict: try Int32.column(of: stmt, at: 5) != 0
      )
    }
  }

  /// Information about an index attached to a table.
  public struct IndexListInfo: Sendable {
    /// Index sequence number.
    public let seq: Int32

    /// Index name.
    public let name: String

    /// Whether this is a unique index.
    public let unique: Bool

    /// How the index was created — `"c"` (CREATE INDEX), `"u"` (UNIQUE), or `"pk"` (PRIMARY KEY).
    public let origin: String

    /// Whether this is a partial index (defined with a `WHERE` clause).
    public let partial: Bool
  }

  /// Lists all indexes attached to a table.
  ///
  /// ```swift
  /// for index in try await db.indexList("users") {
  ///   let kind = index.unique ? " (UNIQUE)" : ""
  ///   print("\(index.name)\(kind)")
  /// }
  /// ```
  public func indexList(_ tableName: String) async throws -> [IndexListInfo] {
    try await query("PRAGMA index_list(\(tableName, mode: .raw))") { stmt, _ in
      IndexListInfo(
        seq: try Int32.column(of: stmt, at: 0),
        name: try String.column(of: stmt, at: 1),
        unique: try Int32.column(of: stmt, at: 2) != 0,
        origin: try String.column(of: stmt, at: 3),
        partial: try Int32.column(of: stmt, at: 4) != 0
      )
    }
  }

  /// Information about a single column within an index.
  public struct IndexColumnInfo: Sendable {
    /// Rank of the column within the index (0-based).
    public let seqno: Int32

    /// Rank of the column within the table — `-1` for rowid, `-2` for an expression.
    public let cid: Int32

    /// Column name, or `nil` for an indexed expression.
    public let name: String?

    /// Sort order — `false` for `ASC`, `true` for `DESC`.
    public let desc: Bool

    /// Collation name (e.g. `"BINARY"`, `"NOCASE"`).
    public let coll: String

    /// Whether the column is part of the index key as opposed to an `INCLUDE`d column.
    public let key: Bool
  }

  /// Returns the column composition of an index.
  ///
  /// ```swift
  /// for column in try await db.indexInfo("idx_users_email") {
  ///   if let name = column.name {
  ///     print("\(name) \(column.desc ? "DESC" : "ASC") COLLATE \(column.coll)")
  ///   }
  /// }
  /// ```
  public func indexInfo(_ indexName: String) async throws -> [IndexColumnInfo] {
    try await query("PRAGMA index_xinfo(\(indexName, mode: .raw))") { stmt, _ in
      IndexColumnInfo(
        seqno: try Int32.column(of: stmt, at: 0),
        cid: try Int32.column(of: stmt, at: 1),
        name: try String?.column(of: stmt, at: 2),
        desc: try Int32.column(of: stmt, at: 3) != 0,
        coll: try String.column(of: stmt, at: 4),
        key: try Int32.column(of: stmt, at: 5) != 0
      )
    }
  }

  /// Information about a foreign key constraint.
  public struct ForeignKeyInfo: Sendable {
    /// Foreign key sequence number.
    public let id: Int32

    /// Sequence number of this column within the foreign key.
    public let seq: Int32

    /// Referenced table name.
    public let table: String

    /// Column name in the current table.
    public let from: String

    /// Column name in the referenced table.
    public let to: String

    /// Action on `UPDATE` (e.g. `"CASCADE"`, `"SET NULL"`, `"RESTRICT"`).
    public let onUpdate: String

    /// Action on `DELETE` (e.g. `"CASCADE"`, `"SET NULL"`, `"RESTRICT"`).
    public let onDelete: String

    /// Match type — usually `"NONE"`.
    public let match: String
  }

  /// Lists all foreign key constraints declared on a table.
  ///
  /// ```swift
  /// for fk in try await db.foreignKeyList("posts") {
  ///   print("\(fk.from) -> \(fk.table).\(fk.to)")
  ///   print("  ON UPDATE \(fk.onUpdate)")
  ///   print("  ON DELETE \(fk.onDelete)")
  /// }
  /// ```
  public func foreignKeyList(_ tableName: String) async throws -> [ForeignKeyInfo] {
    try await query("PRAGMA foreign_key_list(\(tableName, mode: .raw))") { stmt, _ in
      ForeignKeyInfo(
        id: try Int32.column(of: stmt, at: 0),
        seq: try Int32.column(of: stmt, at: 1),
        table: try String.column(of: stmt, at: 2),
        from: try String.column(of: stmt, at: 3),
        to: try String.column(of: stmt, at: 4),
        onUpdate: try String.column(of: stmt, at: 5),
        onDelete: try String.column(of: stmt, at: 6),
        match: try String.column(of: stmt, at: 7)
      )
    }
  }
}
