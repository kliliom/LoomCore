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
    try db.exec("CREATE TABLE test (id INTEGER)")
    try db.exec("INSERT INTO test (id) VALUES (1)")

    db.kill()

    // Verify database is closed
    #expect(throws: LoomError.core(.databaseClosed, message: "Database connection closed.")) {
      try db.exec("SELECT * FROM test")
    }
  }

  @Test("Multiple in-memory databases are independent")
  func testMultipleInMemoryDatabases() async throws {
    let db1 = try Database.openInMemory()
    let db2 = try Database.openInMemory()

    try db1.exec("CREATE TABLE test (value TEXT)")
    try db1.exec("INSERT INTO test (value) VALUES ('db1')")

    try db2.exec("CREATE TABLE test (value TEXT)")
    try db2.exec("INSERT INTO test (value) VALUES ('db2')")

    db1.kill()

    #expect(throws: LoomError.core(.databaseClosed, message: "Database connection closed.")) {
      try db1.exec("SELECT * FROM test")
    }

    let result = try db2.query("SELECT value FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result[0] == "db2")
  }

  @Test("Kill file-based database")
  func testKillFileDatabase() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let dbPath = tempDir.appendingPathComponent("test-\(UUID().uuidString).db")

    defer {
      try? FileManager.default.removeItem(at: dbPath)
    }

    let db = try Database.open(url: dbPath)

    try db.exec("CREATE TABLE test (id INTEGER)")
    try db.exec("INSERT INTO test (id) VALUES (42)")

    db.kill()

    #expect(throws: LoomError.core(.databaseClosed, message: "Database connection closed.")) {
      try db.exec("SELECT * FROM test")
    }
  }
}
