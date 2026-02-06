import Foundation
import SQLite3

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
/// to the database. Resource cleanup — including cached prepared statements and the
/// database connection — is managed by the underlying ``DatabaseHandle``.
///
/// ## Usage
///
/// Create a database using one of the static factory methods:
///
/// ```swift
/// // In-memory database
/// let db = try await Database.openInMemory()
///
/// // File-based database
/// let db = try await Database.open(url: fileURL)
/// ```
///
/// Then use ``exec(_:)`` for writes and ``query(_:stepper:)`` for reads:
///
/// ```swift
/// try db.exec("INSERT INTO users (name) VALUES (\(name))")
///
/// let names = try db.query("SELECT name FROM users") { stmt, _ in
///   try String.column(of: stmt, at: 0)
/// }
/// ```
///
/// - Important: Instances are automatically isolated to ``DatabaseActor``. All database
///              operations are serialized through this actor to prevent race conditions.
@DatabaseActor
public final class Database: Sendable {
  /// The underlying SQLite database connection and its associated resources.
  ///
  /// The handle owns the raw `sqlite3*` pointer and the prepared statement cache.
  /// When this `Database` instance is deallocated, the handle's `deinit` schedules
  /// cleanup of all resources on ``DatabaseActor``.
  let db: DatabaseHandle

  /// Runtime configuration flags controlling caching and transaction state.
  var options: DatabaseOptions = []

  /// Registered services keyed by their metatype identity.
  ///
  /// Services are singletons per type within a database instance. They are created
  /// lazily via ``getService(_:)`` and removed via ``shutdownService(_:)``.
  var services: [ObjectIdentifier: Service] = [:]

  /// Creates a new database instance wrapping an existing connection.
  ///
  /// - Parameter db: The database handle to manage. Ownership is transferred
  ///                 to this instance via `consuming` semantics.
  init(db: consuming DatabaseHandle) {
    self.db = db
  }
}
