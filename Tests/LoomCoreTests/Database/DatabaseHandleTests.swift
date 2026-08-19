import Foundation
import LoomCore
import Testing

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
