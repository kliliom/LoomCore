import Foundation
import SQLite3

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

  /// Token of the innermost open transaction scope (savepoint scopes included), or `nil`
  /// when no transaction is active. Operations gate on this — see `Database+Gate.swift`.
  var activeTransactionToken: TransactionToken?

  /// Tasks suspended on the gate, waiting for the active transaction scope to close.
  var transactionWaiters: [(id: UInt64, continuation: CheckedContinuation<Void, any Error>)] = []

  /// Monotonic source of waiter identifiers, used to remove cancelled waiters.
  var nextWaiterID: UInt64 = 0

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
  /// Deliberately synchronous and exempt from transaction gating, so it can serve as an
  /// escape hatch for a stuck transaction: closing the connection makes the transaction's
  /// remaining statements — and any waiting operations — fail with `.databaseClosed`.
  ///
  /// Statements in flight when `close()` runs keep working — an iteration in progress
  /// continues to completion — and the connection is fully released once their handles
  /// are destroyed. Only new operations throw.
  ///
  /// ```swift
  /// let db = try await Database.open(url: tempURL)
  /// defer { Task { @DatabaseActor in db.close() } }
  /// try await db.exec("…")
  /// ```
  public func close() {
    handle.close()
    // Wake the gate so queued operations observe the closed handle instead of waiting
    // on a transaction that can no longer finish. An in-flight transaction's own scope
    // close tolerates the cleared token.
    activeTransactionToken = nil
    resumeTransactionWaiters()
  }
}
