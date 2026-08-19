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
  /// Commits if the block returns normally; rolls back and rethrows if it throws. The block
  /// receives the database it runs on and may suspend freely — atomicity is preserved across
  /// `await`s.
  ///
  /// ```swift
  /// try await db.transaction { db in
  ///   let balances = try await db.query("SELECT balance FROM accounts WHERE id = \(fromID)") { stmt, _ in
  ///     try Int.column(of: stmt, at: 0)
  ///   }
  ///   guard let fromBalance = balances.first, fromBalance >= amount else {
  ///     throw TransferError.insufficientFunds
  ///   }
  ///   try await db.exec("UPDATE accounts SET balance = balance - \(amount) WHERE id = \(fromID)")
  ///   try await db.exec("UPDATE accounts SET balance = balance + \(amount) WHERE id = \(toID)")
  /// }
  /// ```
  ///
  /// ## Concurrency semantics
  ///
  /// While the transaction is in flight — including while its body is suspended at an
  /// `await` — database operations from tasks outside the transaction suspend and resume
  /// once it commits or rolls back. Membership is tracked by a task-local token bound
  /// around `block`: structured children (`async let`, task groups) and unstructured
  /// `Task {}` inherit it and operate inside the transaction; `Task.detached` does not
  /// and waits like any outside caller — awaiting a detached task from the body therefore
  /// deadlocks. A waiting operation whose task is cancelled throws `CancellationError`.
  ///
  /// An unstructured `Task {}` spawned in the body must complete before the body returns
  /// (`await` its value). A task that outlives the body races the commit: its statements
  /// may run after the transaction ends, outside it, and a nested `transaction` call from
  /// such a task fails once the enclosing scope closes underneath it.
  ///
  /// Transactions on *different* databases nest freely, but two tasks acquiring the same
  /// databases in opposite orders deadlock, exactly like locks. Acquire multiple
  /// databases' transactions in one consistent order.
  ///
  /// Registered services receive ``Service/transactionWillBegin()``,
  /// ``Service/transactionDidCommit()``, and ``Service/transactionDidRollback()``
  /// callbacks at the matching lifecycle points of the outermost transaction. The set of
  /// participating services is fixed when the transaction begins — a service registered
  /// while it is in flight receives no callbacks until the next transaction.
  ///
  /// ## Nested calls
  ///
  /// Calling `transaction` from inside an active transaction opens a `SAVEPOINT` scope:
  /// the nested block's work is released into the enclosing transaction when it returns
  /// normally, and rolled back to the savepoint — leaving the enclosing transaction's
  /// work intact — when it throws. Nested scopes fire no service callbacks (those describe
  /// the physical transaction), and `kind` is ignored because savepoints have no locking
  /// mode. Everything, savepoints included, becomes durable only when the outermost
  /// transaction commits.
  ///
  /// - Parameter kind: Locking mode for the `BEGIN` statement. Defaults to
  ///   ``TransactionKind/deferred``. Ignored for nested (savepoint) scopes.
  /// - Throws: Rethrows any error from `block`; throws `LoomError` if the
  ///   `BEGIN`, `COMMIT`, `SAVEPOINT`, or `RELEASE` itself fails. A failed rollback of
  ///   the outermost transaction closes the underlying handle before rethrowing; a failed
  ///   savepoint rollback leaves the handle open so the outermost transaction can still
  ///   roll everything back.
  public func transaction<T>(
    kind: TransactionKind = .deferred,
    _ block: @DatabaseActor (Database) async throws -> T
  ) async throws -> T {
    try await gate()
    // gate() is same-actor and its final condition check runs in the same synchronous
    // stretch as this claim — no other task can slip in between.
    let previous = activeTransactionToken
    let token = TransactionToken(parent: TransactionToken.current, depth: (previous?.depth ?? 0) + 1)
    activeTransactionToken = token
    defer {
      closeScope(token, restoring: previous)
      resumeTransactionWaiters()
    }

    if previous == nil {
      return try await runTransaction(kind: kind, token: token, block)
    } else {
      return try await runSavepoint(token: token, block)
    }
  }

  /// Uninstalls `token` on scope exit, tolerating out-of-order closes.
  ///
  /// Scopes normally close LIFO, but an un-awaited `Task {}` that inherited the token can
  /// open a nested scope and outlive this one. Restoring `previous` blindly would then
  /// reinstall a token that no live task's chain contains, wedging the gate forever.
  private func closeScope(_ token: TransactionToken, restoring previous: TransactionToken?) {
    if activeTransactionToken === token {
      activeTransactionToken = previous
    } else if let active = activeTransactionToken, TransactionToken.chain(startingAt: active, contains: token) {
      // A nested scope is still open while its enclosing scope exits. The physical
      // transaction is gone, so clear down to this scope's enclosing state; the orphaned
      // scope's own close finds its token already uninstalled and leaves the state alone.
      warn("Transaction scope closed while a nested scope was still open; was a Task left un-awaited?")
      activeTransactionToken = previous
    }
    // Otherwise an enclosing scope already cleared this token: leave the state alone.
  }

  private func runTransaction<T>(
    kind: TransactionKind,
    token: TransactionToken,
    _ block: @DatabaseActor (Database) async throws -> T
  ) async throws -> T {
    let beginStatement =
      switch kind {
      case .deferred:
        "BEGIN DEFERRED TRANSACTION"
      case .immediate:
        "BEGIN IMMEDIATE TRANSACTION"
      case .exclusive:
        "BEGIN EXCLUSIVE TRANSACTION"
      }

    // Machinery statements bypass the gate: the token is installed but not yet bound
    // as the task-local, and the transaction must never wait on itself. BEGIN runs
    // before the service hooks so a failed BEGIN fires none of them.
    try execCore(raw: beginStatement)

    return try await TransactionToken.$current.withValue(token) {
      let participants = signalTransactionWillBegin()
      do {
        let result = try await block(self)
        try execCore(raw: "COMMIT TRANSACTION")
        signalTransactionDidCommit(to: participants)
        return result
      } catch {
        do {
          try execCore(raw: "ROLLBACK TRANSACTION")
          signalTransactionDidRollback(to: participants)
        } catch {
          warn("Failed to rollback transaction: \(error)")
          handle.close()
        }
        throw error
      }
    }
  }

  private func runSavepoint<T>(
    token: TransactionToken,
    _ block: @DatabaseActor (Database) async throws -> T
  ) async throws -> T {
    // Depth-based names recur across transactions (sibling scopes serialize, so at most
    // one scope per depth is open), keeping the statement cache bounded.
    let name = "loom_sp_\(token.depth)"

    try execCore(raw: "SAVEPOINT \(name)")

    return try await TransactionToken.$current.withValue(token) {
      do {
        let result = try await block(self)
        try execCore(raw: "RELEASE SAVEPOINT \(name)")
        return result
      } catch {
        do {
          // ROLLBACK TO undoes the work but keeps the savepoint on the stack;
          // RELEASE closes the scope.
          try execCore(raw: "ROLLBACK TO SAVEPOINT \(name)")
          try execCore(raw: "RELEASE SAVEPOINT \(name)")
        } catch {
          // Unlike the outermost path, do not close the handle: the enclosing
          // transaction's full ROLLBACK can still recover the connection.
          warn("Failed to rollback savepoint: \(error)")
        }
        throw error
      }
    }
  }
}
