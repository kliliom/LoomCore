/// Transaction gate: suspends operations from tasks outside the active transaction scope.
///
/// The gate is what makes `await` inside a transaction body safe. `DatabaseActor` releases
/// its executor at every suspension point, so without the gate another task's statements
/// would run inside the open transaction. Instead, every gated operation waits here until
/// the transaction (or innermost savepoint scope) closes.

extension Database {
  /// Suspends until no foreign transaction scope is active on this database.
  ///
  /// Zero-cost when no transaction is active: one nil check, no suspension. Tasks whose
  /// token chain contains the active token (the transaction body and its structured
  /// children) pass through immediately.
  ///
  /// Mechanism is resume-all-and-recheck: when a scope closes, every waiter is resumed and
  /// re-evaluates the condition. Plain operations never contend with each other — only a
  /// waiting `transaction` call can close the gate again, making the other resumed waiters
  /// loop back into the queue. A queued transaction can in principle be starved by a
  /// continuous stream of competing transactions, but that requires a pathological workload.
  ///
  /// Note: `DatabaseHandle.deinit` cleanup is not gated — if the last reference to a
  /// `Database` drops while a transaction is suspended, the connection can close mid-flight.
  /// That is pre-existing behavior; waiters then fail with `.databaseClosed`.
  func gate() async throws {
    while let active = activeTransactionToken, !TransactionToken.currentChainContains(active) {
      try await waitForTransactionEnd()
    }
  }

  /// Suspends the current task until ``resumeTransactionWaiters()`` runs or the task is
  /// cancelled, whichever comes first.
  func waitForTransactionEnd() async throws {
    let id = nextWaiterID
    nextWaiterID += 1
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
        // This closure runs synchronously on DatabaseActor, so nothing — including the
        // onCancel hop below — can interleave between the caller's gate check and the
        // append. Cancellation has three timings, all safe: before this closure runs,
        // `Task.isCancelled` catches it here; while queued, `cancelWaiter` finds the
        // waiter by id and resumes it throwing; after normal resumption, `cancelWaiter`
        // finds nothing and no-ops.
        if Task.isCancelled {
          continuation.resume(throwing: CancellationError())
        } else if activeTransactionToken == nil {
          continuation.resume()
        } else {
          transactionWaiters.append((id: id, continuation: continuation))
        }
      }
    } onCancel: {
      Task { @DatabaseActor in
        self.cancelWaiter(id: id)
      }
    }
  }

  private func cancelWaiter(id: UInt64) {
    guard let index = transactionWaiters.firstIndex(where: { $0.id == id }) else { return }
    transactionWaiters.remove(at: index).continuation.resume(throwing: CancellationError())
  }

  /// Resumes every queued waiter; each re-checks the gate condition in its own loop.
  func resumeTransactionWaiters() {
    let waiters = transactionWaiters
    transactionWaiters.removeAll()
    for waiter in waiters {
      waiter.continuation.resume()
    }
  }
}
