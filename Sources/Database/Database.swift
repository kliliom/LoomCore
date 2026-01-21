import Foundation
import SQLite3

/// Global actor that serializes access to SQLite database operations.
///
/// This actor ensures thread-safe database operations by serializing all database
/// access through a single actor instance. Functions and types marked with
/// `@DatabaseActor` are isolated to this actor's execution context, preventing
/// concurrent access issues with SQLite.
///
/// SQLite has limited thread-safety guarantees, so this actor provides safe
/// concurrent access by ensuring operations are executed serially.
@globalActor public actor DatabaseActor: GlobalActor {
  public static let shared = DatabaseActor()
}

/// Wrapper type for a handle to an SQLite database connection.
///
/// This type manages the lifetime of an SQLite database connection (`sqlite3*` pointer).
/// It uses Swift's non-copyable types (`~Copyable`) to ensure exclusive ownership and
/// prevent use-after-free errors or double-close bugs.
///
/// The database connection is automatically closed when this handle is deinitialized,
/// ensuring proper resource cleanup even in error scenarios.
///
/// - Important: This type is not copyable to maintain exclusive ownership of the
///              database connection. Pass it using `consuming` or `borrowing` semantics.
public struct DatabaseHandle: ~Copyable, Sendable {
  /// Raw SQLite database connection pointer.
  ///
  /// Marked `nonisolated(unsafe)` to allow access outside the actor context.
  /// Callers must ensure proper synchronization through ``DatabaseActor``.
  nonisolated(unsafe) let ptr: OpaquePointer

  /// Creates a new database handle wrapping an SQLite connection.
  ///
  /// - Parameter ptr: Raw SQLite database connection pointer from `sqlite3_open()`.
  init(ptr: OpaquePointer) {
    self.ptr = ptr
  }

  /// Closes the SQLite database connection when the handle is destroyed.
  ///
  /// If closing fails (which is rare but can happen if prepared statements are still
  /// active), a warning is logged. The connection is considered closed regardless.
  deinit {
    if sqlite3_close(ptr) != SQLITE_OK {
      let message = String(cString: sqlite3_errmsg(ptr))
      warn("Failed to close database: \(message)")
    }
  }
}

/// Runtime configuration flags for database behavior.
///
/// These options control various database features like statement caching and
/// transaction state tracking. They are stored as a bitset to allow combining
/// multiple options efficiently.
struct DatabaseOptions: OptionSet {
  let rawValue: UInt32

  /// Enables prepared statement caching for improved performance.
  ///
  /// When enabled, compiled SQL statements are cached and reused across executions
  /// instead of being re-parsed each time. This significantly improves performance
  /// for frequently executed queries.
  static let persistent = DatabaseOptions(rawValue: 1 << 0)

  /// Indicates an active transaction is in progress.
  ///
  /// This flag tracks whether a BEGIN TRANSACTION has been issued without a
  /// corresponding COMMIT or ROLLBACK, preventing nested transactions or
  /// operations that require no active transaction.
  static let transactionActive = DatabaseOptions(rawValue: 1 << 1)
}

/// Thread-safe interface for interacting with an SQLite database.
///
/// This class provides a high-level API for database operations while managing the
/// underlying SQLite connection lifecycle, statement caching, and transaction state.
///
/// All public methods are isolated to ``DatabaseActor``, ensuring thread-safe access
/// to the database. The class handles automatic cleanup of resources including cached
/// prepared statements and the database connection itself.
///
/// - Important: Instances are automatically isolated to ``DatabaseActor``. All database
///              operations are serialized through this actor to prevent race conditions.
@DatabaseActor
public final class Database: Sendable {
  /// The underlying SQLite database connection.
  let db: DatabaseHandle

  /// Runtime configuration flags controlling caching and transaction state.
  var options: DatabaseOptions = []

  /// Cache of compiled SQL statements for reuse.
  ///
  /// Maps SQL strings to their compiled statement pointers (stored as `UInt` for safety).
  /// Cached statements are automatically finalized when the database is deinitialized.
  var statementCache: [String: UInt] = [:]

  /// Registered services.
  var services: [ObjectIdentifier: Service] = [:]

  /// Creates a new database instance wrapping an existing connection.
  ///
  /// - Parameter db: The database handle to manage. Ownership is transferred to this instance.
  init(db: consuming DatabaseHandle) {
    self.db = db
  }

  /// Finalizes all cached prepared statements before closing the database.
  ///
  /// Cached statements must be finalized before the database connection is closed
  /// to prevent resource leaks and ensure clean shutdown.
  deinit {
    for (_, stmtPtr) in statementCache {
      guard let ptr = OpaquePointer(bitPattern: stmtPtr) else { continue }
      sqlite3_finalize(ptr)
    }
  }
}
