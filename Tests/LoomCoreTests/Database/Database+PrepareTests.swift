import Foundation
import LoomCore
import Testing

/// Covers the single-statement contract enforced by `prepare(sql:)`.
///
/// Before the `pzTail` check, `sqlite3_prepare_v3` compiled the first statement and dropped
/// the rest with no error, so multi-statement migrations shipped half-applied in silence.
@Suite("Database Prepare Tests")
@DatabaseActor
struct DatabasePrepareTests {

  @Test("Trailing statement is rejected instead of silently dropped")
  func testTrailingStatementRejected() async throws {
    let db = try Database.openInMemory()

    await #expect(throws: LoomError.self) {
      try await db.exec(raw: "CREATE TABLE first (x); CREATE TABLE second (x)")
    }

    // The rejected call must not have applied its first statement either.
    let tables = try await db.tableList().map(\.name)
    #expect(!tables.contains("first"))
    #expect(!tables.contains("second"))
  }

  @Test("Trailing statement error carries the trailingSQL code")
  func testTrailingStatementErrorCode() async throws {
    let db = try Database.openInMemory()

    do {
      try await db.exec(raw: "SELECT 1; SELECT 2")
      Issue.record("Expected a trailingSQL error")
    } catch let error as LoomError {
      #expect(error.core == .trailingSQL)
    }
  }

  @Test("Trailing whitespace, semicolons, and comments are accepted")
  func testBenignTrailingTextAccepted() async throws {
    let db = try Database.openInMemory()

    try await db.exec(raw: "CREATE TABLE t (x)")
    try await db.exec(raw: "INSERT INTO t VALUES (1);")
    try await db.exec(raw: "INSERT INTO t VALUES (2);  ")
    try await db.exec(raw: "INSERT INTO t VALUES (3); -- trailing line comment")
    try await db.exec(raw: "INSERT INTO t VALUES (4) /* trailing block comment */")
    try await db.exec(raw: "INSERT INTO t VALUES (5);\n/* multi\n   line */\n")

    let count = try await db.query("SELECT COUNT(*) FROM t") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(count.first == 5)
  }

  @Test("Query rejects trailing statements too")
  func testQueryRejectsTrailingStatement() async throws {
    let db = try Database.openInMemory()

    await #expect(throws: LoomError.self) {
      _ = try await db.query(raw: "SELECT 1; SELECT 2") { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }
    }
  }

  @Test("SQL containing an embedded NUL byte is rejected outright")
  func testEmbeddedNULRejected() async throws {
    let db = try Database.openInMemory()
    try await db.exec(raw: "CREATE TABLE users (id INTEGER PRIMARY KEY)")

    // SQLite's prepare stops at the first zero byte, so without the guard the second
    // statement would be silently dropped instead of raising trailingSQL.
    do {
      try await db.exec(raw: "SELECT 1\0; DROP TABLE users")
      Issue.record("Expected a trailingSQL error")
    } catch let error as LoomError {
      #expect(error.core == .trailingSQL)
    }

    let tables = try await db.tableList().map(\.name)
    #expect(tables.contains("users"))
  }

  @Test("Injected trailing statement cannot ride along")
  func testInjectedTrailingStatementRejected() async throws {
    let db = try Database.openInMemory()
    try await db.exec(raw: "CREATE TABLE users (id INTEGER PRIMARY KEY)")

    await #expect(throws: LoomError.self) {
      try await db.exec(raw: "SELECT 1; DROP TABLE users")
    }

    let tables = try await db.tableList().map(\.name)
    #expect(tables.contains("users"))
  }
}
