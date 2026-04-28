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

/// SQLite database connection serialized through ``DatabaseActor``.
///
/// Owns the underlying `sqlite3*` handle, the prepared-statement cache, and any registered
/// services. Every public method is `@DatabaseActor`-isolated, so the compiler enforces that
/// SQLite access happens on a single concurrency context — there is no internal locking.
/// Cleanup of the connection and cached statements is driven by ``DatabaseHandle``'s deinit.
///
/// Open a database with one of the static factory methods, then use ``exec(_:)`` for writes
/// and ``query(_:stepper:)`` for reads:
///
/// ```swift
/// let db = try await Database.openInMemory()
/// try await db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL)")
///
/// let name = "Alice"
/// try await db.exec("INSERT INTO users (name) VALUES (\(name))")
///
/// let names = try await db.query("SELECT name FROM users") { stmt, _ in
///   try String.column(of: stmt, at: 0)
/// }
/// ```
///
/// File-backed databases use ``open(url:)``:
///
/// ```swift
/// let url = URL(fileURLWithPath: "/tmp/app.sqlite")
/// let db = try await Database.open(url: url)
/// ```
@DatabaseActor
public final class Database: Sendable {
  /// The underlying SQLite database connection and its associated resources.
  ///
  /// The handle owns the raw `sqlite3*` pointer and the prepared statement cache.
  /// When this `Database` instance is deallocated, the handle's `deinit` schedules
  /// cleanup of all resources on ``DatabaseActor``.
  var handle: DatabaseHandle

  /// Runtime configuration flags controlling caching and transaction state.
  var options: DatabaseOptions = []

  /// Registered services keyed by their metatype identity.
  ///
  /// Services are singletons per type within a database instance. They are created
  /// lazily via ``getService(_:)`` and removed via ``shutdownService(_:)``.
  var services: [ObjectIdentifier: Service] = [:]

  /// Creates a new database instance wrapping an existing connection.
  ///
  /// - Parameter handle: The database handle to manage. Ownership is transferred to
  ///   this instance via `consuming` semantics.
  init(handle: consuming DatabaseHandle) {
    self.handle = handle
  }

  /// Closes the SQLite connection and finalizes every cached prepared statement.
  ///
  /// Use this when deterministic resource release is required rather than relying on
  /// deallocation timing — for example, before deleting the underlying database file
  /// or when running large numbers of short-lived connections in tests. Any subsequent
  /// operation on this database will throw.
  ///
  /// ```swift
  /// let db = try await Database.open(url: tempURL)
  /// defer { Task { @DatabaseActor in db.close() } }
  /// try await db.exec("…")
  /// ```
  public func close() {
    handle.close()
  }
}
