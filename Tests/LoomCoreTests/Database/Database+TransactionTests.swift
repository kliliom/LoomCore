import Foundation
import LoomCore
import Testing

@Suite("Database Transaction Tests")
@DatabaseActor
struct DatabaseTransactionTests {
  @Test("Transaction commit")
  func testTransactionCommit() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")

    try await db.transaction { db in
      try await db.exec("INSERT INTO test (value) VALUES (1)")
      try await db.exec("INSERT INTO test (value) VALUES (2)")
    }

    let result = try await db.query("SELECT COUNT(*) FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 2)
  }

  @Test("Transaction rollback on error")
  func testTransactionRollback() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")

    do {
      try await db.transaction { db in
        try await db.exec("INSERT INTO test (value) VALUES (1)")
        throw LoomError.core(.unexpectedState, message: "test error")
      }
    } catch {
      // Expected error
    }

    let result = try await db.query("SELECT COUNT(*) FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 0)
  }

  @Test("Transaction with deferred mode")
  func testTransactionDeferred() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")

    try await db.transaction(kind: .deferred) { db in
      try await db.exec("INSERT INTO test (value) VALUES (1)")
    }

    let result = try await db.query("SELECT value FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 1)
  }

  @Test("Transaction with immediate mode")
  func testTransactionImmediate() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")

    try await db.transaction(kind: .immediate) { db in
      try await db.exec("INSERT INTO test (value) VALUES (1)")
    }

    let result = try await db.query("SELECT value FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 1)
  }

  @Test("Transaction with exclusive mode")
  func testTransactionExclusive() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")

    try await db.transaction(kind: .exclusive) { db in
      try await db.exec("INSERT INTO test (value) VALUES (1)")
    }

    let result = try await db.query("SELECT value FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 1)
  }

  @Test("Transaction with last inserted row ID")
  func testTransactionWithLastInsertedRowID() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")

    let insertedId = try await db.transaction { db in
      try await db.lastInsertedRowID {
        try await db.exec("INSERT INTO test (value) VALUES (42)")
      }
    }

    guard let insertedId else {
      #expect(Bool(false), "No inserted ID returned")
      return
    }

    let result = try await db.query("SELECT value FROM test WHERE rowid = \(insertedId)") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 42)
  }

  @Test("Transaction with multiple operations")
  func testTransactionMultipleOperations() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    try await db.exec("CREATE TABLE posts (id INTEGER PRIMARY KEY, user_id INTEGER, content TEXT)")

    try await db.transaction { db in
      let userId = try await db.lastInsertedRowID {
        try await db.exec("INSERT INTO users (name) VALUES ('Alice')")
      }
      try await db.exec("INSERT INTO posts (user_id, content) VALUES (\(userId), 'Hello')")
    }

    let result = try await db.query(
      """
      SELECT users.name, posts.content
      FROM users
      JOIN posts ON users.id = posts.user_id
      """
    ) { stmt, _ in
      let name = try String.column(of: stmt, at: 0)
      let content = try String.column(of: stmt, at: 1)
      return (name, content)
    }

    #expect(result.first?.0 == "Alice")
    #expect(result.first?.1 == "Hello")
  }

  @Test("Transaction isolation")
  func testTransactionIsolation() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")
    try await db.exec("INSERT INTO test (value) VALUES (1)")

    try await db.transaction { db in
      try await db.exec("UPDATE test SET value = 2")

      let result = try await db.query("SELECT value FROM test") { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }
      #expect(result.first == 2)
    }

    let finalResult = try await db.query("SELECT value FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(finalResult.first == 2)
  }

  @Test("Transaction rollback preserves original data")
  func testTransactionRollbackPreservesData() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")
    try await db.exec("INSERT INTO test (value) VALUES (1)")

    do {
      try await db.transaction { db in
        try await db.exec("UPDATE test SET value = 2")
        try await db.exec("INSERT INTO test (value) VALUES (3)")
        throw LoomError.core(.unexpectedState, message: "test error")
      }
    } catch {
      // Expected error
    }

    let result = try await db.query("SELECT value FROM test ORDER BY value") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.count == 1)
    #expect(result.first == 1)
  }

  @Test("Transaction with constraint violation rolls back")
  func testTransactionConstraintViolation() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, value INTEGER)")
    try await db.exec("INSERT INTO test (id, value) VALUES (1, 100)")

    do {
      try await db.transaction { db in
        try await db.exec("INSERT INTO test (id, value) VALUES (2, 200)")
        // This should violate primary key constraint
        try await db.exec("INSERT INTO test (id, value) VALUES (1, 300)")
      }
    } catch {
      // Expected constraint violation
    }

    let result = try await db.query("SELECT COUNT(*) FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    // Should only have the original row
    #expect(result.first == 1)
  }
}
