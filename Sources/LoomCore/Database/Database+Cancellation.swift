/// Task-cancellation support: cancelling a task aborts its in-flight statement.
///
/// Statements run synchronously on `DatabaseActor`, so the abort signal comes from off the
/// actor via `sqlite3_interrupt` — see `Interruptor`. Cancellation is ambient, matching the
/// gate: a task cancelled while waiting for a transaction already throws `CancellationError`,
/// and the same now holds mid-statement.

extension Database {
  /// Interrupts the SQL statement currently executing on this connection.
  ///
  /// Safe to call from any thread or task; a no-op once the connection is closed. The
  /// aborted operation throws ``LoomError`` with ``SQLiteResultCode/interrupt``. Inside an
  /// explicit transaction, an interrupted write makes SQLite roll the whole transaction
  /// back; ``transaction(kind:_:)`` recognizes that and reports a rollback rather than
  /// failing the connection.
  ///
  /// Task cancellation triggers this automatically for `exec`, `query`, and `execScript`
  /// (those rethrow `CancellationError` instead); call it directly to abort another task's
  /// long-running query without cancelling that task, or from non-Task contexts.
  public nonisolated func interrupt() {
    interruptor.interrupt()
  }

  /// Runs `body` with an interrupt-on-cancel handler armed, mapping the resulting
  /// `SQLITE_INTERRUPT` failure back to `CancellationError`.
  ///
  /// Call only after `gate()`, never around machinery statements (BEGIN/COMMIT/ROLLBACK/
  /// SAVEPOINT) — a transaction must never interrupt its own rollback. The ticket scopes
  /// the handler so a cancellation firing after `body` returned cannot abort a later
  /// operation. `withTaskCancellationHandler` inherits this method's actor isolation and
  /// starts `body` without suspending (the same property `waitForTransactionEnd` relies
  /// on), so the gate's admission and the statement stay one synchronous stretch.
  func withInterruptOnCancellation<T>(_ body: @DatabaseActor () throws -> T) async throws -> T {
    let ticket = interruptor.acquire()
    defer { interruptor.release(ticket) }
    do {
      return try await withTaskCancellationHandler {
        try Task.checkCancellation()
        return try body()
      } onCancel: {
        interruptor.interrupt(ticket: ticket)
      }
    } catch let error as LoomError where error.sqlite == .interrupt && Task.isCancelled {
      throw CancellationError()
    }
  }
}
