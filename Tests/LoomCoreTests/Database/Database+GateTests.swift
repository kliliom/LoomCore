import Foundation
import Testing

@testable import LoomCore

/// Ordered record of checkpoints reached by concurrently running tasks. All appends happen
/// on `DatabaseActor`, so the array order is the authoritative interleaving order.
@DatabaseActor
private final class EventLog {
  var events: [String] = []

  func append(_ event: String) {
    events.append(event)
  }
}

/// One-shot handshake between concurrently running tasks. Used to hold an outside task back
/// until a transaction has provably claimed the gate — plain `Task`/`async let` scheduling
/// order is not guaranteed, so without it the outside operation can run first and never queue.
private struct Signal: Sendable {
  private let stream: AsyncStream<Void>
  private let continuation: AsyncStream<Void>.Continuation

  init() {
    (stream, continuation) = AsyncStream.makeStream()
  }

  func fire() {
    continuation.yield(())
  }

  func wait() async {
    var iterator = stream.makeAsyncIterator()
    _ = await iterator.next()
  }
}

/// Yields the actor until `db` has at least `count` queued gate waiters, failing instead of
/// hanging if they never arrive. Called from inside a transaction body to deterministically
/// hold the transaction open until a competing task is provably suspended on the gate.
@DatabaseActor
private func waitForWaiters(on db: Database, count: Int = 1) async {
  var attempts = 0
  while db.transactionWaiters.count < count {
    attempts += 1
    if attempts > 100_000 {
      Issue.record("Timed out waiting for \(count) gate waiter(s).")
      return
    }
    await Task.yield()
  }
}

@Suite("Database Gate Tests")
struct DatabaseGateTests {
  @Test("Outside operation waits for commit")
  func outsideOperationWaitsForCommit() async throws {
    let db = try await Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")
    let log = EventLog()
    let claimed = Signal()

    async let outside: Void = {
      await claimed.wait()
      // Suspends on the gate until the transaction below commits.
      try await db.exec("INSERT INTO t (value) VALUES (2)")
      await log.append("outside-exec-done")
    }()

    try await db.transaction { db in
      claimed.fire()
      try await db.exec("INSERT INTO t (value) VALUES (1)")
      log.append("body-insert")
      await waitForWaiters(on: db)
      log.append("body-done")
    }

    try await outside

    let events = await log.events
    #expect(events == ["body-insert", "body-done", "outside-exec-done"])

    let count = try await db.query("SELECT COUNT(*) FROM t") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(count.first == 2)
  }

  @Test("Structured children inherit the transaction token")
  func structuredChildrenInheritToken() async throws {
    let db = try await Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")

    try await db.transaction { db in
      try await db.exec("INSERT INTO t (value) VALUES (1)")

      // Both children run inside the transaction: they pass the gate and see
      // the uncommitted row.
      async let asyncLetCount = db.query("SELECT COUNT(*) FROM t") { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }
      let groupCount = try await withThrowingTaskGroup(of: Int.self) { group in
        group.addTask {
          try await Self.insertAndCount(on: db)
        }
        return try await group.next() ?? -1
      }

      #expect(try await asyncLetCount.first.map { $0 >= 1 } == true)
      #expect(groupCount == 2)
    }
  }

  @DatabaseActor
  private static func insertAndCount(on db: Database) async throws -> Int {
    try await db.exec("INSERT INTO t (value) VALUES (2)")
    let rows = try await db.query("SELECT COUNT(*) FROM t") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    return rows.first ?? -1
  }

  @Test("Concurrent transactions serialize")
  func concurrentTransactionsSerialize() async throws {
    let db = try await Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")
    let log = EventLog()

    @Sendable func run(_ name: String, value: Int) async throws {
      try await db.transaction { db in
        log.append("\(name)-begin")
        try await db.exec("INSERT INTO t (value) VALUES (\(value))")
        // Suspend mid-body so a broken gate would let the other transaction in.
        await Task.yield()
        try await db.exec("INSERT INTO t (value) VALUES (\(value))")
        log.append("\(name)-end")
      }
    }

    async let first: Void = run("t1", value: 1)
    async let second: Void = run("t2", value: 2)
    try await first
    try await second

    let events = await log.events
    #expect(events.count == 4)
    // Each transaction's begin must be immediately followed by its own end.
    if events.count == 4 {
      let name = events[0].prefix(2)
      #expect(events[1] == "\(name)-end")
      #expect(events[3].hasSuffix("-end"))
      #expect(events[2].prefix(2) == events[3].prefix(2))
    }

    let count = try await db.query("SELECT COUNT(*) FROM t") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(count.first == 4)
  }

  @Test("Cancelled waiter throws CancellationError and leaves the database usable")
  func cancelledWaiterThrows() async throws {
    let db = try await Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")

    let claimed = Signal()
    let release = Signal()

    let transactionTask = Task {
      try await db.transaction { db in
        claimed.fire()
        try await db.exec("INSERT INTO t (value) VALUES (1)")
        await waitForWaiters(on: db)
        await release.wait()
      }
    }

    await claimed.wait()
    let waiterTask = Task {
      try await db.exec("INSERT INTO t (value) VALUES (2)")
    }

    // Hold until the waiter is provably queued, then cancel it.
    await waitForWaiters(on: db)
    waiterTask.cancel()

    await #expect(throws: CancellationError.self) {
      try await waiterTask.value
    }

    release.fire()
    try await transactionTask.value

    let values = try await db.query("SELECT value FROM t ORDER BY value") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(values == [1])
  }

  @Test("Nested transaction commits into the outer transaction")
  func nestedTransactionCommits() async throws {
    let db = try await Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")

    try await db.transaction { db in
      try await db.exec("INSERT INTO t (value) VALUES (1)")
      try await db.transaction { db in
        try await db.exec("INSERT INTO t (value) VALUES (2)")
      }
    }

    let values = try await db.query("SELECT value FROM t ORDER BY value") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(values == [1, 2])
  }

  @Test("Nested transaction rollback preserves outer work")
  func nestedTransactionRollbackPreservesOuterWork() async throws {
    let db = try await Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")

    try await db.transaction { db in
      try await db.exec("INSERT INTO t (value) VALUES (1)")
      try? await db.transaction { db in
        try await db.exec("INSERT INTO t (value) VALUES (2)")
        throw LoomError.core(.unexpectedState, message: "inner failure")
      }
      try await db.exec("INSERT INTO t (value) VALUES (3)")
    }

    let values = try await db.query("SELECT value FROM t ORDER BY value") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(values == [1, 3])
  }

  @Test("Outer rollback discards released nested work")
  func outerRollbackDiscardsNestedWork() async throws {
    let db = try await Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")

    try? await db.transaction { db in
      try await db.transaction { db in
        try await db.exec("INSERT INTO t (value) VALUES (1)")
      }
      throw LoomError.core(.unexpectedState, message: "outer failure")
    }

    let count = try await db.query("SELECT COUNT(*) FROM t") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(count.first == 0)
  }

  @Test("Savepoints nest three levels deep")
  func savepointsNestThreeLevels() async throws {
    let db = try await Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")

    try await db.transaction { db in
      try await db.exec("INSERT INTO t (value) VALUES (1)")
      try await db.transaction { db in
        try await db.exec("INSERT INTO t (value) VALUES (2)")
        try? await db.transaction { db in
          try await db.exec("INSERT INTO t (value) VALUES (3)")
          throw LoomError.core(.unexpectedState, message: "deepest failure")
        }
      }
    }

    let values = try await db.query("SELECT value FROM t ORDER BY value") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(values == [1, 2])
  }

  @Test("Sibling nested transactions serialize their savepoint scopes")
  func siblingSavepointsSerialize() async throws {
    let db = try await Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")
    let log = EventLog()

    try await db.transaction { db in
      @Sendable func nested(_ name: String, value: Int) async throws {
        try await db.transaction { db in
          log.append("\(name)-begin")
          try await db.exec("INSERT INTO t (value) VALUES (\(value))")
          await Task.yield()
          try await db.exec("INSERT INTO t (value) VALUES (\(value))")
          log.append("\(name)-end")
        }
      }

      async let first: Void = nested("s1", value: 1)
      async let second: Void = nested("s2", value: 2)
      try await first
      try await second
    }

    let events = await log.events
    #expect(events.count == 4)
    if events.count == 4 {
      // SQLite savepoints form a stack, so sibling scopes must not overlap.
      #expect(events[1].prefix(2) == events[0].prefix(2))
      #expect(events[3].prefix(2) == events[2].prefix(2))
    }

    let count = try await db.query("SELECT COUNT(*) FROM t") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(count.first == 4)
  }

  @Test("Service hooks fire only for the outermost transaction")
  func serviceHooksFireOnlyForOutermostTransaction() async throws {
    let db = try await Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")
    let service = await db.getService(HookCounter.self)

    try await db.transaction { db in
      try await db.exec("INSERT INTO t (value) VALUES (1)")
      try? await db.transaction { db in
        try await db.exec("INSERT INTO t (value) VALUES (2)")
        throw LoomError.core(.unexpectedState, message: "inner failure")
      }
      try await db.transaction { db in
        try await db.exec("INSERT INTO t (value) VALUES (3)")
      }
    }

    let (begins, commits, rollbacks) = await (service.begins, service.commits, service.rollbacks)
    #expect(begins == 1)
    #expect(commits == 1)
    #expect(rollbacks == 0)
  }

  @Test("Queued operation proceeds after rollback")
  func queuedOperationProceedsAfterRollback() async throws {
    let db = try await Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")

    let claimed = Signal()

    async let outside: Void = {
      await claimed.wait()
      try await db.exec("INSERT INTO t (value) VALUES (2)")
    }()

    try? await db.transaction { db in
      claimed.fire()
      try await db.exec("INSERT INTO t (value) VALUES (1)")
      await Task.yield()
      try await db.exec("INSERT INTO t (value) VALUES (1)")
      await waitForWaiters(on: db)
      throw LoomError.core(.unexpectedState, message: "body failure")
    }

    try await outside

    // The transaction's inserts rolled back; the gated outside insert must not
    // have joined the transaction, so it survives.
    let values = try await db.query("SELECT value FROM t ORDER BY value") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(values == [2])
  }

  @Test("Cross-database nesting keeps both transactions usable")
  func crossDatabaseNesting() async throws {
    let dbA = try await Database.openInMemory()
    let dbB = try await Database.openInMemory()
    try await dbA.exec("CREATE TABLE a (value INTEGER)")
    try await dbB.exec("CREATE TABLE b (value INTEGER)")

    try await dbA.transaction { dbA in
      try await dbA.exec("INSERT INTO a (value) VALUES (1)")
      // Plain ops on B pass immediately: B has no active transaction.
      try await dbB.exec("INSERT INTO b (value) VALUES (1)")

      try await dbB.transaction { dbB in
        try await dbB.exec("INSERT INTO b (value) VALUES (2)")
        // Ops on A inside B's body still match A's token through the parent chain.
        try await dbA.exec("INSERT INTO a (value) VALUES (2)")
      }

      try await dbA.exec("INSERT INTO a (value) VALUES (3)")
    }

    let aCount = try await dbA.query("SELECT COUNT(*) FROM a") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    let bCount = try await dbB.query("SELECT COUNT(*) FROM b") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(aCount.first == 3)
    #expect(bCount.first == 2)
  }

  @Test("close() wakes gate waiters instead of leaving them suspended")
  func closeWakesGateWaiters() async throws {
    let db = try await Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")
    let claimed = Signal()
    let release = Signal()

    let transactionTask = Task {
      try await db.transaction { db in
        claimed.fire()
        try await db.exec("INSERT INTO t (value) VALUES (1)")
        await waitForWaiters(on: db)
        await release.wait()
      }
    }

    await claimed.wait()
    let waiterTask = Task {
      try await db.exec("INSERT INTO t (value) VALUES (2)")
    }
    await waitForWaiters(on: db)

    // The documented escape hatch: closing must fail the queued waiter, not strand it.
    await db.close()
    await #expect(throws: LoomError.self) {
      try await waiterTask.value
    }

    release.fire()
    await #expect(throws: LoomError.self) {
      try await transactionTask.value
    }
  }

  @Test("lastInsertedRowID from outside waits for the transaction")
  func lastInsertedRowIDGates() async throws {
    let db = try await Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")
    let claimed = Signal()

    async let outside: Int64? = {
      await claimed.wait()
      // Must queue on the gate; running its reset early would zero the
      // transaction's rowid state mid-flight.
      return try await db.lastInsertedRowID {}
    }()

    try await db.transaction { db in
      claimed.fire()
      let id = try await db.lastInsertedRowID {
        try await db.exec("INSERT INTO t (value) VALUES (1)")
        await waitForWaiters(on: db)
      }
      #expect(id != nil)
    }

    _ = try await outside
  }

  @Test("Savepoint statements do not grow the statement cache per iteration")
  func savepointStatementsCacheBounded() async throws {
    let db = try await Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")

    try await db.cached {
      for value in 0..<5 {
        try await db.transaction { db in
          try await db.transaction { db in
            try await db.exec("INSERT INTO t (value) VALUES (\(value))")
          }
        }
      }
    }

    // Machinery statements (BEGIN/COMMIT/SAVEPOINT/RELEASE) bypass the statement cache,
    // so per-scope-unique savepoint names cannot grow it; only the INSERT stays cached.
    #expect(await cacheCount(on: db) == 1)
  }

  @Test("cached scope does not leak to other databases")
  func cachedScopeIsPerDatabase() async throws {
    let dbA = try await Database.openInMemory()
    let dbB = try await Database.openInMemory()
    try await dbB.exec("CREATE TABLE b (value INTEGER)")

    try await dbA.cached {
      try await dbB.exec("INSERT INTO b (value) VALUES (1)")
    }

    #expect(await cacheCount(on: dbB) == 0)
  }

  @Test("Service registered mid-transaction receives no unpaired hooks")
  func midTransactionServiceRegistration() async throws {
    let db = try await Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")

    try await db.transaction { db in
      try await db.exec("INSERT INTO t (value) VALUES (1)")
      _ = db.getService(HookCounter.self)
    }

    let service = await db.getService(HookCounter.self)
    #expect(await (service.begins, service.commits, service.rollbacks) == (0, 0, 0))

    try await db.transaction { _ in }
    #expect(await (service.begins, service.commits) == (1, 1))
  }

  @Test("Un-awaited nested scope cannot wedge the gate")
  func orphanedNestedScopeDoesNotWedgeGate() async throws {
    let db = try await Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")
    let release = Signal()

    // The outer body spawns a nested transaction in a fire-and-forget Task and returns
    // while that savepoint scope is still open — a documented misuse. It must fail
    // loudly, not leave a dead token wedging the gate or close the connection.
    let orphan: Task<Void, any Error> = try await db.transaction { db in
      try await db.exec("INSERT INTO t (value) VALUES (1)")
      let orphan = Task {
        try await db.transaction { db in
          try await db.exec("INSERT INTO t (value) VALUES (2)")
          await release.wait()
        }
      }
      var attempts = 0
      while (db.activeTransactionToken?.depth ?? 0) < 2, attempts < 100_000 {
        attempts += 1
        await Task.yield()
      }
      return orphan
    }

    release.fire()
    // The orphaned scope's close is refused: its savepoint's fate was decided by the
    // outer COMMIT, so its RELEASE must never reach the connection.
    do {
      try await orphan.value
      Issue.record("Orphaned scope's close should throw")
    } catch let error as LoomError {
      #expect(error.core == .transactionScopeLost)
    }

    // The gate must not be wedged and the connection must still be usable.
    try await db.exec("INSERT INTO t (value) VALUES (3)")
    let values = try await db.query("SELECT value FROM t ORDER BY value") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(values == [1, 2, 3])
  }

  @Test("Orphaned scope's close cannot disturb a later transaction's savepoint")
  func orphanedScopeCannotDisturbForeignSavepoint() async throws {
    let db = try await Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")
    struct IntendedRollback: Error {}
    let releaseOrphan = Signal()
    let t2Suspended = Signal()
    let orphanRefused = Signal()

    // T1 spawns an un-awaited Task holding a savepoint scope open, then commits — the
    // documented misuse. The orphan's scope-closing RELEASE will run much later.
    let orphan: Task<Void, any Error> = try await db.transaction { db in
      let orphan = Task {
        try await db.transaction { _ in
          await releaseOrphan.wait()
        }
      }
      var attempts = 0
      while (db.activeTransactionToken?.depth ?? 0) < 2, attempts < 100_000 {
        attempts += 1
        await Task.yield()
      }
      return orphan
    }

    // T2 opens its own nested scope and suspends inside it, so the orphan's close runs
    // while a foreign savepoint is the connection's most recent one. Historically the
    // orphan's RELEASE resolved against it, silently committing T2's rolled-back insert.
    let t2 = Task {
      try await db.transaction { db in
        try await db.exec("INSERT INTO t (value) VALUES (1)")
        do {
          try await db.transaction { db in
            try await db.exec("INSERT INTO t (value) VALUES (2)")
            t2Suspended.fire()
            await orphanRefused.wait()
            throw IntendedRollback()
          }
        } catch is IntendedRollback {
          // Expected: the nested scope threw, so its insert must be gone.
        }
      }
    }

    await t2Suspended.wait()
    releaseOrphan.fire()
    do {
      try await orphan.value
      Issue.record("Orphaned scope's close should be refused")
    } catch let error as LoomError {
      #expect(error.core == .transactionScopeLost)
    }
    orphanRefused.fire()
    try await t2.value

    let values = try await db.query("SELECT value FROM t ORDER BY value") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(values == [1])
  }

  @Test("Task.detached does not inherit the transaction token")
  func detachedTaskDoesNotInheritToken() async throws {
    let db = try await Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")
    let detachedDone = Signal()

    // The detached task must queue at the gate like any outside caller; if it
    // inherited the token it would pass straight through and `waitForWaiters`
    // would time out. Its insert runs after the rollback, outside the
    // transaction, so it must survive while the body's insert must not.
    @Sendable @DatabaseActor func detachedInsert() async {
      do {
        try await db.exec("INSERT INTO t (value) VALUES (2)")
      } catch {
        Issue.record("Detached insert failed: \(error)")
      }
      detachedDone.fire()
    }
    try? await db.transaction { db in
      try await db.exec("INSERT INTO t (value) VALUES (1)")
      Task.detached {
        await detachedInsert()
      }
      await waitForWaiters(on: db)
      throw LoomError.core(.unexpectedState, message: "body failure")
    }

    await detachedDone.wait()

    let values = try await db.query("SELECT value FROM t ORDER BY value") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(values == [2])
  }

  @Test("Unstructured Task inherits the token and joins the transaction")
  func unstructuredTaskInheritsToken() async throws {
    let db = try await Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")

    // The Task {} inside the body inherits the task-local token (SE-0311), so its
    // insert is part of the transaction and rolls back with it.
    try? await db.transaction { db in
      let child = Task {
        try await db.exec("INSERT INTO t (value) VALUES (1)")
      }
      try await child.value
      throw LoomError.core(.unexpectedState, message: "body failure")
    }

    let count = try await db.query("SELECT COUNT(*) FROM t") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(count.first == 0)
  }
}

@DatabaseActor
private func cacheCount(on db: Database) -> Int {
  db.handle.resourceStore.statementCache.count
}

@DatabaseActor
private final class HookCounter: Database.Service {
  var begins = 0
  var commits = 0
  var rollbacks = 0

  override func transactionWillBegin() { begins += 1 }
  override func transactionDidCommit() { commits += 1 }
  override func transactionDidRollback() { rollbacks += 1 }
}
