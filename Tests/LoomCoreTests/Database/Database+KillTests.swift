import Foundation
import LoomCore
import Testing

@Suite("Database Killing Tests")
@DatabaseActor
struct DatabaseKillTests {
  @Test("Kill in-memory database")
  func testKillInMemory() async throws {
    let db = try Database.openInMemory()

    // Verify database is usable
    try await db.exec("CREATE TABLE test (id INTEGER)")
    try await db.exec("INSERT INTO test (id) VALUES (1)")

    db.close()

    // Verify database is closed
    await #expect(throws: LoomError.core(.databaseClosed, message: "Database connection closed.")) {
      try await db.exec("SELECT * FROM test")
    }
  }

  @Test("Multiple in-memory databases are independent")
  func testMultipleInMemoryDatabases() async throws {
    let db1 = try Database.openInMemory()
    let db2 = try Database.openInMemory()

    try await db1.exec("CREATE TABLE test (value TEXT)")
    try await db1.exec("INSERT INTO test (value) VALUES ('db1')")

    try await db2.exec("CREATE TABLE test (value TEXT)")
    try await db2.exec("INSERT INTO test (value) VALUES ('db2')")

    db1.close()

    await #expect(throws: LoomError.core(.databaseClosed, message: "Database connection closed.")) {
      try await db1.exec("SELECT * FROM test")
    }

    let result = try await db2.query("SELECT value FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result[0] == "db2")
  }

  @Test("Kill file-based database")
  func testKillFileDatabase() async throws {
    let url = tmpDatabaseURL()
    let db = try Database.open(url: url)

    defer {
      db.close()
      url.remove()
    }

    try await db.exec("CREATE TABLE test (id INTEGER)")
    try await db.exec("INSERT INTO test (id) VALUES (42)")

    db.close()

    await #expect(throws: LoomError.core(.databaseClosed, message: "Database connection closed.")) {
      try await db.exec("SELECT * FROM test")
    }
  }
}
