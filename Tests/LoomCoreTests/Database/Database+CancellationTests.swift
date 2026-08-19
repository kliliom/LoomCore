import Foundation
import Testing

@testable import LoomCore

@Suite("Database Cancellation Tests")
@DatabaseActor
struct DatabaseCancellationTests {
  @Test("Cancelling mid-iteration interrupts the query and throws CancellationError")
  func testMidIterationCancel() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE t (a INTEGER)")
    try await db.exec("INSERT INTO t (a) VALUES (1), (2), (3), (4), (5)")

    let task = Task { @DatabaseActor in
      try await db.query(raw: "SELECT a FROM t") { (stmt: borrowing StatementHandle, stop: inout Bool) -> Int in
        // Cancelling the running task fires the interrupt handler inline, so the
        // next step aborts deterministically.
        withUnsafeCurrentTask { $0?.cancel() }
        return try Int.column(of: stmt, at: 0)
      }
    }
    await #expect(throws: CancellationError.self) {
      try await task.value
    }

    // The connection is untouched; later work proceeds normally.
    let count = try await db.query("SELECT COUNT(*) FROM t") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(count == [5])
  }

  @Test("Cancellation aborts a single long-running step")
  func testSingleLongStepCancel() async throws {
    let db = try Database.openInMemory()

    // One step that would take far longer than the test allows; only a sub-step
    // interrupt can end it early.
    let longQuery = """
      WITH RECURSIVE c(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM c LIMIT 100000000)
      SELECT COUNT(*) FROM c
      """
    let task = Task { @DatabaseActor in
      try await db.query(raw: longQuery) { (stmt: borrowing StatementHandle, stop: inout Bool) -> Int in
        try Int.column(of: stmt, at: 0)
      }
    }
    // The cancel must come from off the actor: the step occupies DatabaseActor
    // synchronously, so an actor-isolated canceller could not run until too late.
    let canceller = Task.detached {
      try await Task.sleep(for: .milliseconds(50))
      task.cancel()
    }

    await #expect(throws: CancellationError.self) {
      try await task.value
    }
    try await canceller.value

    let one = try await db.query("SELECT 1") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(one == [1])
  }

  @Test("A pre-cancelled task executes nothing")
  func testPreCancelledTask() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE t (a INTEGER)")

    let task = Task { @DatabaseActor in
      withUnsafeCurrentTask { $0?.cancel() }
      try await db.exec("INSERT INTO t (a) VALUES (99)")
    }
    await #expect(throws: CancellationError.self) {
      try await task.value
    }

    let count = try await db.query("SELECT COUNT(*) FROM t") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(count == [0])
  }

  @Test("Explicit interrupt surfaces as a LoomError, not CancellationError")
  func testExplicitInterrupt() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE t (a INTEGER)")
    try await db.exec("INSERT INTO t (a) VALUES (1), (2), (3)")

    do {
      _ = try await db.query(raw: "SELECT a FROM t") { (stmt: borrowing StatementHandle, stop: inout Bool) -> Int in
        db.interrupt()
        return try Int.column(of: stmt, at: 0)
      }
      Issue.record("Interrupted query should throw")
    } catch let error as LoomError {
      // The task was not cancelled, so no CancellationError mapping applies.
      #expect(error.sqlite == .interrupt)
    }

    // The connection stays usable.
    let count = try await db.query("SELECT COUNT(*) FROM t") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(count == [3])
  }

  @Test("Interrupt inside a transaction rolls back and keeps the connection open")
  func testInterruptInsideTransaction() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE t (a INTEGER)")
    let service = db.getService(RollbackObserver.self)

    do {
      try await db.transaction { db in
        try await db.exec("INSERT INTO t (a) VALUES (1)")
        _ = try await db.query(raw: "INSERT INTO t (a) VALUES (10), (11), (12) RETURNING a") {
          (stmt: borrowing StatementHandle, stop: inout Bool) -> Int in
          db.interrupt()
          return try Int.column(of: stmt, at: 0)
        }
      }
      Issue.record("Interrupted transaction should throw")
    } catch let error as LoomError {
      #expect(error.sqlite == .interrupt)
    }

    #expect(service.rollbacks == 1)
    #expect(service.commits == 0)

    // The connection survives (no handle.close() on this path) and the
    // transaction's work is gone — SQLite's auto-rollback and the machinery's
    // autocommit reconciliation agree.
    try await db.exec("INSERT INTO t (a) VALUES (2)")
    let values = try await db.query("SELECT a FROM t ORDER BY a") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(values == [2])
  }

  @Test("Interrupt inside a savepoint scope rolls back and keeps the connection open")
  func testInterruptInsideSavepoint() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE t (a INTEGER)")

    do {
      try await db.transaction { db in
        try await db.exec("INSERT INTO t (a) VALUES (1)")
        try await db.transaction { db in
          _ = try await db.query(raw: "INSERT INTO t (a) VALUES (10), (11) RETURNING a") {
            (stmt: borrowing StatementHandle, stop: inout Bool) -> Int in
            db.interrupt()
            return try Int.column(of: stmt, at: 0)
          }
        }
      }
      Issue.record("Interrupted transaction should throw")
    } catch {
      // Depending on SQLite's rollback timing this is the interrupt error or the
      // enclosing scope's transactionScopeLost — either way the connection must
      // survive and the work must be gone.
    }

    try await db.exec("INSERT INTO t (a) VALUES (2)")
    let values = try await db.query("SELECT a FROM t ORDER BY a") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(values == [2])
  }

  @Test("interrupt() after close is a no-op")
  func testInterruptAfterClose() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE t (a INTEGER)")
    db.close()
    // Must not crash: the Interruptor was invalidated before sqlite3_close_v2.
    db.interrupt()
  }

  @Test("A stale ticket cannot interrupt a later operation")
  func testStaleTicketDoesNotInterrupt() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE t (a INTEGER)")
    try await db.exec("INSERT INTO t (a) VALUES (1), (2)")

    // A ticket released (or superseded) before the interrupt fires must be a
    // no-op — this is what stops a late-firing cancellation handler from
    // aborting an unrelated task's statement.
    let stale = db.interruptor.acquire()
    db.interruptor.release(stale)
    db.interruptor.interrupt(ticket: stale)

    let superseded = db.interruptor.acquire()
    _ = db.interruptor.acquire()
    db.interruptor.interrupt(ticket: superseded)

    let values = try await db.query("SELECT a FROM t ORDER BY a") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(values == [1, 2])
  }
}

@DatabaseActor
private final class RollbackObserver: Database.Service {
  var commits = 0
  var rollbacks = 0

  override func transactionDidCommit() { commits += 1 }
  override func transactionDidRollback() { rollbacks += 1 }
}
