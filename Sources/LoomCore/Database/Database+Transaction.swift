import Foundation
import SQLite3

/// SQLite transaction locking mode.
///
/// Controls when SQLite acquires locks on the database file, trading concurrency
/// against the chance of `SQLITE_BUSY` errors during execution.
public enum TransactionKind: Hashable, Sendable {
  /// Defers lock acquisition until the first read or write inside the transaction.
  ///
  /// Multiple deferred transactions can coexist initially, but conflicts during
  /// execution surface as `SQLITE_BUSY`. Suitable as the default for most workloads
  /// where contention is rare.
  case deferred

  /// Acquires a reserved write lock when the transaction begins.
  ///
  /// Other connections can still read but cannot write until commit or rollback.
  /// Use when the transaction is known to write and you want to fail fast on
  /// contention rather than partway through.
  case immediate

  /// Acquires an exclusive lock when the transaction begins.
  ///
  /// Blocks all other readers and writers until commit or rollback. Reserve for
  /// operations that genuinely require full isolation, such as migrations or
  /// schema rewrites.
  case exclusive
}

extension Database {
  /// Runs a block of operations atomically inside a transaction.
  ///
  /// Commits if the block returns normally; rolls back and rethrows if it throws.
  ///
  /// ```swift
  /// try db.transaction {
  ///   let fromBalance: Int = try db.queryOne("SELECT balance FROM accounts WHERE id = \(fromID)")
  ///   guard fromBalance >= amount else { throw TransferError.insufficientFunds }
  ///   try db.exec("UPDATE accounts SET balance = balance - \(amount) WHERE id = \(fromID)")
  ///   try db.exec("UPDATE accounts SET balance = balance + \(amount) WHERE id = \(toID)")
  /// }
  /// ```
  ///
  /// Registered services receive ``Service/transactionWillBegin()``,
  /// ``Service/transactionDidCommit()``, and ``Service/transactionDidRollback()``
  /// callbacks at the matching lifecycle points.
  ///
  /// ## Nested calls
  ///
  /// Nested transactions are not supported. Calling `transaction` while one is
  /// already active logs a warning and runs `block` inside the existing
  /// transaction without issuing `SAVEPOINT`.
  ///
  /// - Parameter kind: Locking mode for the `BEGIN` statement. Defaults to
  ///   ``TransactionKind/deferred``.
  /// - Throws: Rethrows any error from `block`; throws `LoomError` if the
  ///   `BEGIN` or `COMMIT` itself fails. A failed rollback closes the underlying
  ///   handle before rethrowing.
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
