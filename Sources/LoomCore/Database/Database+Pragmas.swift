/// Convenience methods for accessing SQLite PRAGMA statements.
///
/// This extension provides type-safe, high-level access to commonly used SQLite PRAGMA
/// statements for configuring database behavior, querying metadata, and performing
/// maintenance operations.
///
/// ## PRAGMA Categories
///
/// - **Configuration**: Control database behavior (journal mode, synchronous, cache size, etc.)
/// - **Maintenance**: Perform database maintenance (optimize, vacuum, integrity check)
/// - **Introspection**: Query database schema and metadata (table info, indexes, foreign keys)
///
/// ## Thread Safety
///
/// All PRAGMA methods are isolated to ``DatabaseActor``, ensuring thread-safe access to
/// the database configuration.

import Foundation
import SQLite3

// MARK: - Journal Mode

extension Database {
  /// SQLite journal mode controls how the rollback journal is managed.
  ///
  /// The journal mode affects durability, performance, and concurrency characteristics.
  public enum JournalMode: String, Sendable, CaseIterable {
    /// DELETE mode (default) - Journal file deleted after each transaction.
    ///
    /// This is the traditional SQLite behavior. Good balance of safety and performance
    /// for single-connection use.
    case delete = "DELETE"

    /// TRUNCATE mode - Journal file truncated to zero length instead of deleted.
    ///
    /// Slightly faster than DELETE on some systems as it avoids directory changes.
    case truncate = "TRUNCATE"

    /// PERSIST mode - Journal file remains but header is overwritten with zeros.
    ///
    /// Prevents the overhead of deleting and recreating the journal file.
    case persist = "PERSIST"

    /// MEMORY mode - Journal kept in memory rather than on disk.
    ///
    /// Fastest mode but loses rollback capability if process crashes.
    /// Not recommended for production use.
    case memory = "MEMORY"

    /// WAL mode (Write-Ahead Logging) - Changes written to separate WAL file.
    ///
    /// Significantly better concurrency as readers don't block writers.
    /// Recommended for most production applications.
    case wal = "WAL"

    /// OFF mode - No rollback journal (dangerous!).
    ///
    /// Disables rollback and atomic commit. Database may become corrupted
    /// if a crash occurs mid-transaction. Only use for temporary databases.
    case off = "OFF"
  }

  /// Gets the current journal mode.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let mode = try db.getJournalMode()
  /// print("Current journal mode: \(mode)")
  /// ```
  ///
  /// - Returns: The current ``JournalMode``.
  /// - Throws: `LoomError` if the PRAGMA query fails or returns an unexpected value.
  public func getJournalMode() throws -> JournalMode {
    let result = try query("PRAGMA journal_mode") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    guard let modeString = result.first,
      let mode = JournalMode(rawValue: modeString.uppercased())
    else {
      throw LoomError.core(.unexpectedState, message: "Invalid journal_mode value")
    }

    return mode
  }

  /// Sets the journal mode.
  ///
  /// **Note**: Some journal mode changes may fail if incompatible with the current state.
  /// For example, you cannot change to WAL mode if the database file is on a network
  /// filesystem that doesn't support shared memory.
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Enable WAL mode for better concurrency
  /// try db.setJournalMode(.wal)
  /// ```
  ///
  /// - Parameter mode: The ``JournalMode`` to set.
  /// - Throws: `LoomError` if the PRAGMA statement fails.
  @discardableResult
  public func setJournalMode(_ mode: JournalMode) throws -> JournalMode {
    let result = try query("PRAGMA journal_mode = \(mode.rawValue, mode: .raw)") { stmt, _ in
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
  /// SQLite synchronous mode controls how aggressively SQLite syncs to disk.
  ///
  /// This affects the trade-off between durability (data safety) and performance.
  public enum SynchronousMode: Int32, Sendable, CaseIterable {
    /// OFF mode (0) - No syncing (fastest, most dangerous).
    ///
    /// SQLite does not pause to wait for data to reach disk. Database may become
    /// corrupted if the OS crashes or loses power. Only use for temporary data.
    case off = 0

    /// NORMAL mode (1) - Sync at critical moments.
    ///
    /// Syncs at most critical moments. Safe with WAL mode but can corrupt database
    /// in rollback journal modes if OS crashes at wrong time. Good balance for WAL mode.
    case normal = 1

    /// FULL mode (2) - Sync after every transaction (default).
    ///
    /// Ensures data reaches disk before transactions commit. Safest option but slower.
    /// Recommended for important data in DELETE/TRUNCATE/PERSIST journal modes.
    case full = 2

    /// EXTRA mode (3) - Maximum safety.
    ///
    /// Goes beyond FULL to reduce risk of corruption in extremely rare scenarios.
    /// Significantly slower than FULL with minimal additional safety benefit.
    case extra = 3
  }

  /// Gets the current synchronous mode.
  ///
  /// - Returns: The current ``SynchronousMode``.
  /// - Throws: `LoomError` if the PRAGMA query fails or returns an unexpected value.
  public func getSynchronous() throws -> SynchronousMode {
    let result = try query("PRAGMA synchronous") { stmt, _ in
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
  /// - WAL mode: Use `.normal` for good balance of safety and performance
  /// - DELETE/TRUNCATE/PERSIST modes: Use `.full` for safety
  /// - Temporary data only: Can use `.off` for maximum speed
  ///
  /// ## Example
  ///
  /// ```swift
  /// try db.setJournalMode(.wal)
  /// try db.setSynchronous(.normal)  // Good balance for WAL mode
  /// ```
  ///
  /// - Parameter mode: The ``SynchronousMode`` to set.
  /// - Throws: `LoomError` if the PRAGMA statement fails.
  public func setSynchronous(_ mode: SynchronousMode) throws {
    try exec("PRAGMA synchronous = \(mode.rawValue, mode: .raw)")
  }
}

// MARK: - Cache Size

extension Database {
  /// Cache size controls the amount of memory SQLite uses for caching database pages.
  public enum CacheSize: Sendable, Hashable {
    /// Cache size specified in pages.
    case pages(Int32)
    /// Cache size specified in kibibytes.
    case kibibytes(Int32)

    /// Initializes a `CacheSize` from a raw Int32 value returned by SQLite.
    ///
    /// A negative value indicates kibibytes, while a positive value indicates pages.
    /// - Parameter raw: The raw cache size value from SQLite.
    public init(raw: Int32) {
      if raw < 0 {
        self = .kibibytes(-raw)
      } else {
        self = .pages(raw)
      }
    }
  }

  /// Gets the suggested maximum number of database pages held in memory.
  ///
  /// The cache size is measured in pages (typically 4096 bytes each). A negative
  /// value means the cache size is specified in kibibytes.
  ///
  /// - Returns: The cache size as a ``CacheSize`` value.
  /// - Throws: `LoomError` if the PRAGMA query fails.
  public func getCacheSize() throws -> CacheSize {
    let result = try query("PRAGMA cache_size") { stmt, _ in
      try Int32.column(of: stmt, at: 0)
    }

    guard let size = result.first else {
      throw LoomError.core(.unexpectedState, message: "cache_size returned no value")
    }

    return CacheSize(raw: size)
  }

  /// Sets the suggested maximum number of database pages held in memory.
  ///
  /// Larger cache sizes improve performance for read-heavy workloads but use more memory.
  /// The default is usually -2000 (2MB).
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Set cache to 10MB
  /// try db.setCacheSize(.kibibytes(10240))
  ///
  /// // Or set cache to 2560 pages (typically ~10MB with 4KB pages)
  /// try db.setCacheSize(.pages(2560))
  /// ```
  ///
  /// - Parameter size: The cache size in pages (positive) or kibibytes (negative).
  /// - Throws: `LoomError` if the PRAGMA statement fails.
  public func setCacheSize(_ size: CacheSize) throws {
    let rawValue: Int32
    switch size {
    case .pages(let pages):
      rawValue = pages
    case .kibibytes(let kibibytes):
      rawValue = -kibibytes
    }
    try exec("PRAGMA cache_size = \(rawValue, mode: .raw)")
  }
}

// MARK: - Temp Store

extension Database {
  /// Location where temporary tables and indexes are stored.
  public enum TempStoreMode: Int32, Sendable, CaseIterable {
    /// DEFAULT mode (0) - Use compile-time default (usually FILE).
    case `default` = 0

    /// FILE mode (1) - Store temporary tables in files.
    ///
    /// Slower but doesn't use process memory.
    case file = 1

    /// MEMORY mode (2) - Store temporary tables in memory.
    ///
    /// Faster but uses more memory. Recommended for most applications.
    case memory = 2
  }

  /// Gets the current temp_store mode.
  ///
  /// - Returns: The current ``TempStoreMode``.
  /// - Throws: `LoomError` if the PRAGMA query fails or returns an unexpected value.
  public func getTempStore() throws -> TempStoreMode {
    let result = try query("PRAGMA temp_store") { stmt, _ in
      try Int32.column(of: stmt, at: 0)
    }

    guard let value = result.first,
      let mode = TempStoreMode(rawValue: value)
    else {
      throw LoomError.core(.unexpectedState, message: "Invalid temp_store value")
    }

    return mode
  }

  /// Sets the temp_store mode.
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Store temporary tables in memory for better performance
  /// try db.setTempStore(.memory)
  /// ```
  ///
  /// - Parameter mode: The ``TempStoreMode`` to set.
  /// - Throws: `LoomError` if the PRAGMA statement fails.
  public func setTempStore(_ mode: TempStoreMode) throws {
    try exec("PRAGMA temp_store = \(mode.rawValue, mode: .raw)")
  }
}

// MARK: - Memory-Mapped I/O

extension Database {
  /// Gets the maximum number of bytes used for memory-mapped I/O.
  ///
  /// A value of 0 means memory-mapped I/O is disabled.
  ///
  /// - Returns: The maximum mmap size in bytes.
  /// - Throws: `LoomError` if the PRAGMA query fails.
  public func getMmapSize() throws -> Int64 {
    let result = try query("PRAGMA mmap_size") { stmt, _ in
      try Int64.column(of: stmt, at: 0)
    }

    guard let size = result.first else {
      throw LoomError.core(.unexpectedState, message: "mmap_size returned no value")
    }

    return size
  }

  /// Sets the maximum number of bytes used for memory-mapped I/O.
  ///
  /// Memory-mapped I/O can improve performance by allowing SQLite to read database
  /// pages directly from memory without system calls. However, it may cause issues
  /// on some platforms or with very large databases.
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Enable 256MB of memory-mapped I/O
  /// try db.setMmapSize(256 * 1024 * 1024)
  ///
  /// // Disable memory-mapped I/O
  /// try db.setMmapSize(0)
  /// ```
  ///
  /// - Parameter size: The maximum mmap size in bytes (0 to disable).
  /// - Returns: The maximum mmap size in bytes.
  /// - Throws: `LoomError` if the PRAGMA statement fails.
  public func setMmapSize(_ size: Int64) throws -> Int64 {
    let result = try query("PRAGMA mmap_size = \(size, mode: .raw)") { stmt, _ in
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
  /// Gets the foreign key constraints enforcement status.
  ///
  /// Foreign keys are disabled by default for backwards compatibility.
  ///
  /// - Returns: `true` if foreign key constraints are enabled, `false` otherwise.
  /// - Throws: `LoomError` if the PRAGMA query fails.
  public func getForeignKeys() throws -> Bool {
    let result = try query("PRAGMA foreign_keys") { stmt, _ in
      try Int32.column(of: stmt, at: 0)
    }

    return result.first == 1
  }

  /// Sets the foreign key constraints enforcement status.
  ///
  /// **Important**: Foreign key enforcement can only be changed when there are no
  /// active transactions. It's best to set this immediately after opening the database.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let db = try Database.openInMemory()
  /// // Enable foreign key enforcement
  /// try db.setForeignKeys(true)
  /// ```
  ///
  /// - Parameter enabled: Whether to enable foreign key constraint enforcement.
  /// - Throws: `LoomError` if the PRAGMA statement fails.
  public func setForeignKeys(_ enabled: Bool) throws {
    try exec("PRAGMA foreign_keys = \(enabled ? 1 : 0, mode: .raw)")
  }
}

// MARK: - Auto Vacuum

extension Database {
  /// Auto-vacuum mode controls automatic database file size management.
  public enum AutoVacuumMode: Int32, Sendable, CaseIterable {
    /// NONE mode (0) - No automatic vacuuming (default).
    ///
    /// Database file never shrinks. Use manual VACUUM to reclaim space.
    case none = 0

    /// FULL mode (1) - Automatically reclaim freed space after transactions.
    ///
    /// Database file automatically shrinks when data is deleted. Adds overhead
    /// to delete operations.
    case full = 1

    /// INCREMENTAL mode (2) - Allows manual incremental vacuum operations.
    ///
    /// Free pages are marked but not automatically removed. Use
    /// ``incrementalVacuum(pages:)`` to reclaim space in controlled chunks.
    case incremental = 2
  }

  /// Gets the current auto-vacuum mode.
  ///
  /// - Returns: The current ``AutoVacuumMode``.
  /// - Throws: `LoomError` if the PRAGMA query fails or returns an unexpected value.
  public func getAutoVacuum() throws -> AutoVacuumMode {
    let result = try query("PRAGMA auto_vacuum") { stmt, _ in
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
  /// **Important**: Changing auto_vacuum mode requires running VACUUM after setting.
  /// The change only takes effect after the VACUUM completes. This cannot be changed
  /// for attached databases or when transactions are active.
  ///
  /// ## Example
  ///
  /// ```swift
  /// try db.setAutoVacuum(.incremental)
  /// // Must vacuum for change to take effect
  /// try db.vacuum()
  /// ```
  ///
  /// - Parameter mode: The ``AutoVacuumMode`` to set.
  /// - Throws: `LoomError` if the PRAGMA statement fails.
  public func setAutoVacuum(_ mode: AutoVacuumMode) throws {
    try exec("PRAGMA auto_vacuum = \(mode.rawValue, mode: .raw)")
  }
}

// MARK: - Maintenance Operations

extension Database {
  /// Performs an integrity check on the database.
  ///
  /// This runs a comprehensive check of the database structure, verifying that
  /// all B-tree pages are correctly structured and all content can be read.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let issues = try db.integrityCheck()
  /// if issues.isEmpty {
  ///   print("Database integrity OK")
  /// } else {
  ///   print("Database issues found:")
  ///   for issue in issues {
  ///     print("  - \(issue)")
  ///   }
  /// }
  /// ```
  ///
  /// - Parameter maxErrors: Maximum number of errors to return (default: 100).
  /// - Returns: An array of error messages. Empty array means database is OK.
  /// - Throws: `LoomError` if the PRAGMA query fails.
  public func integrityCheck(maxErrors: Int32 = 100) throws -> [String] {
    let results = try query("PRAGMA integrity_check(\(maxErrors, mode: .raw))") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    // "ok" means no errors found
    if results.count == 1 && results[0].lowercased() == "ok" {
      return []
    }

    return results
  }

  /// Attempts to optimize the database.
  ///
  /// This causes SQLite to analyze the database and potentially restructure internal
  /// data to improve query performance. It's safe to run periodically and will only
  /// make changes when they would be beneficial.
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Run optimization (typically at app shutdown or during maintenance)
  /// try db.optimize()
  /// ```
  ///
  /// - Throws: `LoomError` if the PRAGMA statement fails.
  public func optimize() throws {
    try exec("PRAGMA optimize")
  }

  /// Performs a full vacuum operation on the database.
  ///
  /// VACUUM rebuilds the database file, repacking it into a minimal amount of disk space.
  /// This operation:
  /// - Reclaims freed space from deleted data
  /// - Defragments the database for better performance
  /// - Resets auto-increment counters
  /// - Rebuilds indexes
  ///
  /// **Important**: VACUUM requires exclusive access to the database and temporarily uses
  /// up to twice the database size in disk space. It cannot be run inside a transaction
  /// and cannot be used on attached databases.
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Reclaim space after deleting large amounts of data
  /// try db.exec("DELETE FROM old_logs WHERE created_at < ?", binding: cutoffDate)
  /// try db.vacuum()
  /// ```
  ///
  /// ## Performance Considerations
  ///
  /// - VACUUM can be slow on large databases (gigabytes)
  /// - Consider using ``AutoVacuumMode/incremental`` mode with ``incrementalVacuum(pages:)``
  ///   for better control over when space is reclaimed
  /// - For databases in WAL mode, consider ``walCheckpoint(mode:schema:)`` instead
  ///
  /// - Throws: `LoomError` if the vacuum operation fails or if called within a transaction.
  public func vacuum() throws {
    try exec("VACUUM")
  }

  /// Performs an incremental vacuum operation.
  ///
  /// Only works when the database is in ``AutoVacuumMode/incremental`` mode.
  /// Reclaims up to the specified number of free pages, shrinking the database file.
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Ensure database is in incremental vacuum mode first
  /// try db.setAutoVacuum(.incremental)
  /// try db.vacuum()  // Apply the setting
  ///
  /// // Later, reclaim freed space
  /// try db.incrementalVacuum(pages: 100)
  /// ```
  ///
  /// - Parameter pages: Maximum number of pages to remove from the free list.
  ///                    If `nil`, removes all free pages.
  /// - Throws: `LoomError` if the database is not in incremental vacuum mode or
  ///           if the operation fails.
  public func incrementalVacuum(pages: Int32? = nil) throws {
    let statement: SQLStatement =
      if let pages {
        "PRAGMA incremental_vacuum(\(pages, mode: .raw))"
      } else {
        "PRAGMA incremental_vacuum"
      }
    _ = try query(statement) { stmt, _ in }
  }
}

// MARK: - WAL Checkpoint

extension Database {
  /// WAL checkpoint mode determines how aggressively to checkpoint.
  public enum WALCheckpointMode: String, Sendable, CaseIterable {
    /// PASSIVE mode - Checkpoint as much as possible without blocking.
    ///
    /// Does not wait for readers or writers. Checkpoints whatever can be
    /// checkpointed immediately. Recommended for background checkpointing.
    case passive = "PASSIVE"

    /// FULL mode - Block until all pages are checkpointed.
    ///
    /// Waits for readers to finish, then checkpoints entire WAL. May block
    /// for some time if there are active readers.
    case full = "FULL"

    /// RESTART mode - Full checkpoint then restart WAL.
    ///
    /// Like FULL, but also resets the WAL file to the beginning.
    case restart = "RESTART"

    /// TRUNCATE mode - Full checkpoint then truncate WAL to zero bytes.
    ///
    /// Most aggressive checkpointing. Ensures WAL file is removed/emptied.
    case truncate = "TRUNCATE"
  }

  /// Information about a WAL checkpoint operation.
  public struct WALCheckpointInfo: Sendable {
    /// Whether the checkpoint was busy (unable to complete).
    public let busy: Bool

    /// Number of modified pages in the WAL before checkpoint.
    public let logPages: Int32

    /// Number of pages checkpointed.
    public let checkpointedPages: Int32
  }

  /// Performs a WAL checkpoint operation.
  ///
  /// Only applicable when the database is in ``JournalMode/wal`` mode. This operation
  /// transfers data from the WAL file back into the main database file.
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Ensure database is in WAL mode
  /// try db.setJournalMode(.wal)
  ///
  /// // Perform a passive checkpoint (non-blocking)
  /// let info = try db.walCheckpoint(mode: .passive)
  /// print("Checkpointed \(info.checkpointedPages) of \(info.logPages) pages")
  /// ```
  ///
  /// - Parameters:
  ///   - mode: The ``WALCheckpointMode`` to use (default: `.passive`).
  ///   - schema: The schema name to checkpoint (default: `"main"`).
  /// - Returns: ``WALCheckpointInfo`` with details about the checkpoint operation.
  /// - Throws: `LoomError` if the database is not in WAL mode or if the operation fails.
  public func walCheckpoint(
    mode: WALCheckpointMode = .passive,
    schema: String = "main"
  ) throws -> WALCheckpointInfo {
    let results = try query(
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
  /// Information about a table column.
  public struct ColumnInfo: Sendable {
    /// Column index (0-based).
    public let cid: Int32

    /// Column name.
    public let name: String

    /// Column type (e.g., "INTEGER", "TEXT", "REAL", "BLOB").
    public let type: String

    /// Whether the column can be NULL.
    public let notNull: Bool

    /// Default value for the column, if any.
    public let defaultValue: String?

    /// Whether this column is part of the primary key (1-based position, or 0 if not).
    public let pk: Int32
  }

  /// Gets information about the columns in a table.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let columns = try db.tableInfo("users")
  /// for column in columns {
  ///   print("\(column.name): \(column.type)" + (column.notNull ? " NOT NULL" : ""))
  /// }
  /// ```
  ///
  /// - Parameter tableName: The name of the table to inspect.
  /// - Returns: An array of ``ColumnInfo`` describing each column.
  /// - Throws: `LoomError` if the table doesn't exist or the query fails.
  public func tableInfo(_ tableName: String) throws -> [ColumnInfo] {
    try query("PRAGMA table_info(\(tableName, mode: .raw))") { stmt, _ in
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

  /// Information about a table in the database.
  public struct TableInfo: Sendable {
    /// The schema containing the table (e.g., "main", "temp").
    public let schema: String

    /// The table name.
    public let name: String

    /// The type (usually "table" or "view").
    public let type: String

    /// Number of columns in the table.
    public let ncol: Int32

    /// Whether this is a WITHOUT ROWID table.
    public let withoutRowid: Bool

    /// Whether this table is strict.
    public let strict: Bool
  }

  /// Lists all tables in the database.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let tables = try db.tableList()
  /// for table in tables {
  ///   print("Table: \(table.name) (\(table.ncol) columns)")
  /// }
  /// ```
  ///
  /// - Parameter schema: The schema to list tables from (default: `"main"`).
  /// - Returns: An array of ``TableInfo`` describing each table.
  /// - Throws: `LoomError` if the query fails.
  public func tableList(schema: String = "main") throws -> [TableInfo] {
    try query("PRAGMA \(schema, mode: .raw).table_list") { stmt, _ in
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

  /// Information about an index.
  public struct IndexListInfo: Sendable {
    /// Index sequence number.
    public let seq: Int32

    /// Index name.
    public let name: String

    /// Whether this is a unique index.
    public let unique: Bool

    /// How the index was created ("c" = CREATE INDEX, "u" = UNIQUE, "pk" = PRIMARY KEY).
    public let origin: String

    /// Whether this is a partial index.
    public let partial: Bool
  }

  /// Lists all indexes on a table.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let indexes = try db.indexList("users")
  /// for index in indexes {
  ///   print("Index: \(index.name)" + (index.unique ? " (UNIQUE)" : ""))
  /// }
  /// ```
  ///
  /// - Parameter tableName: The name of the table to list indexes for.
  /// - Returns: An array of ``IndexListInfo`` describing each index.
  /// - Throws: `LoomError` if the table doesn't exist or the query fails.
  public func indexList(_ tableName: String) throws -> [IndexListInfo] {
    try query("PRAGMA index_list(\(tableName, mode: .raw))") { stmt, _ in
      IndexListInfo(
        seq: try Int32.column(of: stmt, at: 0),
        name: try String.column(of: stmt, at: 1),
        unique: try Int32.column(of: stmt, at: 2) != 0,
        origin: try String.column(of: stmt, at: 3),
        partial: try Int32.column(of: stmt, at: 4) != 0
      )
    }
  }

  /// Information about a column in an index.
  public struct IndexColumnInfo: Sendable {
    /// Rank of column within index (0-based).
    public let seqno: Int32

    /// Rank of column within table (-1 for rowid, -2 for expression).
    public let cid: Int32

    /// Column name (nil for expressions).
    public let name: String?

    /// Sort order (0 = ASC, 1 = DESC).
    public let desc: Bool

    /// Collation name (e.g., "BINARY", "NOCASE").
    public let coll: String

    /// Whether column is a key (part of index, not just INCLUDE).
    public let key: Bool
  }

  /// Gets information about the columns in an index.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let columns = try db.indexInfo("idx_users_email")
  /// for column in columns {
  ///   if let name = column.name {
  ///     print("\(name) \(column.desc ? "DESC" : "ASC")")
  ///   }
  /// }
  /// ```
  ///
  /// - Parameter indexName: The name of the index to inspect.
  /// - Returns: An array of ``IndexColumnInfo`` describing each column in the index.
  /// - Throws: `LoomError` if the index doesn't exist or the query fails.
  public func indexInfo(_ indexName: String) throws -> [IndexColumnInfo] {
    try query("PRAGMA index_xinfo(\(indexName, mode: .raw))") { stmt, _ in
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

    /// Sequence number within the foreign key.
    public let seq: Int32

    /// Referenced table name.
    public let table: String

    /// Column name in the current table.
    public let from: String

    /// Column name in the referenced table.
    public let to: String

    /// Action on UPDATE (e.g., "CASCADE", "SET NULL", "RESTRICT").
    public let onUpdate: String

    /// Action on DELETE (e.g., "CASCADE", "SET NULL", "RESTRICT").
    public let onDelete: String

    /// Match type (usually "NONE").
    public let match: String
  }

  /// Lists all foreign key constraints on a table.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let foreignKeys = try db.foreignKeyList("posts")
  /// for fk in foreignKeys {
  ///   print("\(fk.from) -> \(fk.table).\(fk.to)")
  ///   print("  ON UPDATE \(fk.onUpdate)")
  ///   print("  ON DELETE \(fk.onDelete)")
  /// }
  /// ```
  ///
  /// - Parameter tableName: The name of the table to list foreign keys for.
  /// - Returns: An array of ``ForeignKeyInfo`` describing each foreign key constraint.
  /// - Throws: `LoomError` if the table doesn't exist or the query fails.
  public func foreignKeyList(_ tableName: String) throws -> [ForeignKeyInfo] {
    try query("PRAGMA foreign_key_list(\(tableName, mode: .raw))") { stmt, _ in
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
