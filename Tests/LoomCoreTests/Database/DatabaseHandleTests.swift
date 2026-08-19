import Foundation
import SQLite3
import Testing

@testable import LoomCore

@Suite("Database Handle Tests")
@DatabaseActor
struct DatabaseHandleTests {
  // Regression for a use-after-free: closing the database while a cached statement
  // was checked out finalized it under the live handle, whose deinit then reset
  // freed memory (SIGSEGV). The checked-out statement must survive the close and
  // be finalized by its own handle.
  @Test("Close inside a stepper with a cached statement does not crash")
  func testCloseWithLiveCachedStatement() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE t (a INTEGER)")
    try await db.exec("INSERT INTO t (a) VALUES (1), (2), (3)")

    try await db.cached {
      _ = try await db.query(raw: "SELECT a FROM t") { (stmt: borrowing StatementHandle, stop: inout Bool) -> Int in
        db.close()
        stop = true
        return 0
      }
      // Returning from `query` destroys the handle over the closed connection.
    }

    await #expect(throws: LoomError.core(.databaseClosed, message: "Database connection closed.")) {
      try await db.exec("SELECT a FROM t")
    }
  }

  @Test("Cached statement cannot be handed out after close")
  func testCacheUnreachableAfterClose() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE t (a INTEGER)")
    try await db.exec("INSERT INTO t (a) VALUES (1)")

    try await db.cached {
      _ = try await db.query(raw: "SELECT a FROM t") { (stmt: borrowing StatementHandle, stop: inout Bool) -> Int in
        db.close()
        stop = true
        return 0
      }
    }

    await #expect(throws: LoomError.core(.databaseClosed, message: "Database connection closed.")) {
      try await db.cached {
        _ = try await db.query(raw: "SELECT a FROM t") { (stmt: borrowing StatementHandle, stop: inout Bool) -> Int in
          stop = true
          return 0
        }
      }
    }
  }

  // Regression for a permanent connection leak: `sqlite3_close` returned
  // SQLITE_BUSY while a statement was live, the pointer was dropped anyway, and
  // the connection kept its file locks forever. With `sqlite3_close_v2` the
  // connection is released once the last live statement is finalized, so a
  // second connection to the same file can write.
  @Test("Close with a live statement releases the connection and its file locks")
  func testCloseWithLiveStatementReleasesConnection() async throws {
    let url = tmpDatabaseURL()
    defer { url.remove() }

    try await holdLockAndCloseInStepper(at: url)

    // Give the DatabaseHandle deinit cleanup Task a chance to run.
    try await Task.sleep(for: .milliseconds(200))

    let second = try Database.open(url: url)
    defer { second.close() }

    try await second.exec("INSERT INTO t (a) VALUES (4)")

    let count = try await second.query("SELECT COUNT(*) FROM t") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(count == [4])
  }

  // `sqlite3_close_v2` is designed for exactly this shape: live statements keep
  // working against the zombie connection (verified empirically), and the
  // connection is freed when the last one is finalized.
  @Test("Iteration in flight when close is called continues to completion")
  func testSteppingAfterCloseContinues() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE t (a INTEGER)")
    try await db.exec("INSERT INTO t (a) VALUES (1), (2), (3)")

    // Close on the first row and keep iterating.
    let rows = try await db.query(raw: "SELECT a FROM t ORDER BY a") {
      (stmt: borrowing StatementHandle, stop: inout Bool) -> Int in
      db.close()
      return try Int.column(of: stmt, at: 0)
    }

    #expect(rows == [1, 2, 3])

    await #expect(throws: LoomError.core(.databaseClosed, message: "Database connection closed.")) {
      try await db.exec("SELECT a FROM t")
    }
  }

  @Test("Repeated close with a live statement is idempotent")
  func testDoubleCloseWithLiveStatement() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE t (a INTEGER)")
    try await db.exec("INSERT INTO t (a) VALUES (1)")

    try await db.cached {
      _ = try await db.query(raw: "SELECT a FROM t") { (stmt: borrowing StatementHandle, stop: inout Bool) -> Int in
        db.close()
        db.close()
        stop = true
        return 0
      }
    }

    db.close()

    await #expect(throws: LoomError.core(.databaseClosed, message: "Database connection closed.")) {
      try await db.exec("SELECT a FROM t")
    }
  }

  @Test("Statement cache evicts the least recently used entry at capacity")
  func testCacheEvictsLeastRecentlyUsed() async throws {
    let db = try Database.openInMemory(statementCacheCapacity: 2)
    try await db.exec("CREATE TABLE t (a INTEGER)")
    let store = db.handle.resourceStore

    let sqlA = "INSERT INTO t (a) VALUES (1)"
    let sqlB = "INSERT INTO t (a) VALUES (2)"
    let sqlC = "INSERT INTO t (a) VALUES (3)"

    try await db.cached {
      try await db.exec(raw: sqlA)
      try await db.exec(raw: sqlB)
      // Touch A so B becomes the least recently used, then C's insert evicts B.
      try await db.exec(raw: sqlA)
      try await db.exec(raw: sqlC)
    }

    #expect(store.statementCache.count == 2)
    #expect(store.statementCache[sqlA] != nil)
    #expect(store.statementCache[sqlB] == nil)
    #expect(store.statementCache[sqlC] != nil)

    // The surviving hot entry still executes correctly after the eviction pass.
    try await db.cached {
      try await db.exec(raw: sqlA)
    }
    let count = try await db.query("SELECT COUNT(*) FROM t WHERE a = 1") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(count == [3])
  }

  @Test("A checked-out statement is never evicted")
  func testCheckedOutStatementSurvivesEviction() async throws {
    let db = try Database.openInMemory(statementCacheCapacity: 1)
    try await db.exec("CREATE TABLE t (a INTEGER)")
    let store = db.handle.resourceStore

    let sqlA = "SELECT a FROM t"
    let sqlB = "SELECT COUNT(*) FROM t"

    try await db.cached {
      do {
        let handleA = try db.prepare(sql: sqlA)
        let ptrA = handleA.stmtPtr
        // The cache is full and its only entry is checked out, so preparing B
        // must overflow the cap instead of evicting A under its live handle.
        do {
          let handleB = try db.prepare(sql: sqlB)
          _ = handleB.stmtPtr
        }
        #expect(store.statementCache[sqlA]?.ptr == ptrA)
        #expect(store.statementCache.count == 2)
      }
    }
    #expect(store.checkedOut.isEmpty)
  }

  @Test("Eviction finalizes the victim instead of leaking it")
  func testEvictionFinalizesVictims() async throws {
    let db = try Database.openInMemory(statementCacheCapacity: 2)
    try await db.exec("CREATE TABLE t (a INTEGER)")

    try await db.cached {
      for value in 0..<10 {
        try await db.exec(raw: "INSERT INTO t (a) VALUES (\(value))")
      }
    }

    #expect(db.handle.resourceStore.statementCache.count == 2)

    // Walk SQLite's own list of live statements: evicted entries must have been
    // finalized, so no more statements survive than the cache holds.
    var liveStatements = 0
    var stmt = sqlite3_next_stmt(try db.handle.ptr, nil)
    while stmt != nil {
      liveStatements += 1
      stmt = sqlite3_next_stmt(try db.handle.ptr, stmt)
    }
    #expect(liveStatements == 2)
  }

  @Test("clearStatementCache empties the cache and later work repopulates it")
  func testClearStatementCache() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE t (a INTEGER)")
    let store = db.handle.resourceStore

    try await db.cached {
      try await db.exec(raw: "INSERT INTO t (a) VALUES (1)")
      try await db.exec(raw: "INSERT INTO t (a) VALUES (2)")
    }
    #expect(store.statementCache.count == 2)

    db.clearStatementCache()
    #expect(store.statementCache.isEmpty)

    try await db.cached {
      try await db.exec(raw: "INSERT INTO t (a) VALUES (3)")
    }
    #expect(store.statementCache.count == 1)

    let values = try await db.query("SELECT a FROM t ORDER BY a") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(values == [1, 2, 3])
  }
}

// Opens a file database, takes the EXCLUSIVE file lock, and closes the database
// from inside a stepper while its (temporary) statement is still live. In its own
// function so the `Database` deinits before the caller reopens the file.
@DatabaseActor
private func holdLockAndCloseInStepper(at url: URL) async throws {
  let db = try Database.open(url: url)

  // Hold the file lock for the connection's lifetime so a leak is observable.
  _ = try await db.query("PRAGMA locking_mode=EXCLUSIVE") { stmt, _ in
    try String.column(of: stmt, at: 0)
  }
  try await db.exec("CREATE TABLE t (a INTEGER)")
  try await db.exec("INSERT INTO t (a) VALUES (1), (2), (3)")

  _ = try await db.query(raw: "SELECT a FROM t") { (stmt: borrowing StatementHandle, stop: inout Bool) -> Int in
    db.close()
    stop = true
    return 0
  }
}
