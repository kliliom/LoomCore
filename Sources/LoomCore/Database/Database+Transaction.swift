import Foundation
import SQLite3

/// SQLite transaction locking mode.
///
/// These modes control when SQLite acquires locks on the database file, affecting
/// concurrency and the potential for lock conflicts.
public enum TransactionKind: Hashable, Sendable {
  /// Deferred transaction - acquires locks only when needed.
  ///
  /// Locks are not acquired until the first read or write operation within the transaction.
  /// This allows multiple deferred transactions to coexist initially, but may lead to
  /// `SQLITE_BUSY` errors if conflicts arise during execution.
  ///
  /// Use this mode (the default) for most transactions to maximize concurrency.
  case deferred

  /// Immediate transaction - acquires a write lock immediately.
  ///
  /// A reserved lock is acquired on the database as soon as the transaction begins,
  /// preventing other connections from writing (but allowing reads). This prevents
  /// `SQLITE_BUSY` errors during the transaction, at the cost of reduced concurrency.
  ///
  /// Use this mode when you know the transaction will perform writes and want to
  /// fail fast if the database is locked.
  case immediate

  /// Exclusive transaction - acquires an exclusive lock immediately.
  ///
  /// An exclusive lock is acquired immediately, preventing all other connections from
  /// reading or writing. This provides maximum isolation but minimum concurrency.
  ///
  /// Use this mode sparingly, only when you need complete isolation from other connections,
  /// such as during database migrations or schema changes.
  case exclusive
}

extension Database {
  /// Executes a block of database operations within a transaction.
  ///
  /// Transactions ensure that a group of database operations either all succeed (commit)
  /// or all fail (rollback), maintaining database consistency. This is essential for
  /// operations that must be atomic, such as transferring data between tables or
  /// maintaining referential integrity across multiple inserts.
  ///
  /// If the block completes successfully, the transaction is committed. If an error is thrown,
  /// the transaction is automatically rolled back, reverting all changes made during the block.
  ///
  /// The following example demonstrates executing multiple SQL statements in a transaction:
  ///
  ///     try db.transaction {
  ///       try db.exec("INSERT INTO users (name, age) VALUES ('Foo', 42)")
  ///       try db.exec("INSERT INTO users (name, age) VALUES ('Bar', 24)")
  ///     }
  ///
  /// - Important: Nested transactions are not supported. If this method is called while a
  ///              transaction is already active, a warning is logged and the block executes
  ///              within the existing transaction instead of creating a new one.
  ///
  /// - Note: All registered services receive transaction lifecycle callbacks
  ///         (``Service/transactionWillBegin()``, ``Service/transactionDidCommit()``,
  ///         ``Service/transactionDidRollback()``) at appropriate points during execution.
  ///
  /// - Parameters:
  ///   - kind: The transaction locking mode. Defaults to ``TransactionKind/deferred`` for
  ///           maximum concurrency. See ``TransactionKind`` for details on each mode.
  ///   - block: A closure containing the database operations to execute atomically.
  ///            Must be isolated to ``DatabaseActor``.
  ///
  /// - Returns: The value returned by the block closure.
  ///
  /// - Throws: `LoomError` if an error occurs while executing the block or interacting with the database.
  ///           If the block throws an error, the transaction is rolled back and the error is rethrown.
  public func transaction<T>(
    kind: TransactionKind = .deferred,
    _ block: @DatabaseActor () throws -> T
  ) throws -> T {
    if options.contains(.transactionActive) {
      warn("Nested transactions are not supported, executing in the current transaction.")
      return try block()
    }

    options.insert(.transactionActive)
    signalTransactionWillBegin()
    defer { options.remove(.transactionActive) }

    let beginStatement =
      switch kind {
      case .deferred:
        "BEGIN DEFERRED TRANSACTION"
      case .immediate:
        "BEGIN IMMEDIATE TRANSACTION"
      case .exclusive:
        "BEGIN EXCLUSIVE TRANSACTION"
      }

    try exec(.raw(beginStatement))

    do {
      let result = try block()
      try exec("COMMIT TRANSACTION")
      signalTransactionDidCommit()
      return result
    } catch {
      do {
        try exec("ROLLBACK TRANSACTION")
        signalTransactionDidRollback()
      } catch {
        warn("Failed to rollback transaction: \(error)")
        handle.close()
      }
      throw error
    }
  }
}
