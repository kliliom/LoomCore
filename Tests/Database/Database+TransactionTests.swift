import Foundation
import LoomCore
import Testing

@Suite("Database Transaction Tests")
@DatabaseActor
struct DatabaseTransactionTests {
  @Test("Transaction commit")
  func testTransactionCommit() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    try db.transaction {
      try db.exec("INSERT INTO test (value) VALUES (1)")
      try db.exec("INSERT INTO test (value) VALUES (2)")
    }

    let result = try db.query("SELECT COUNT(*) FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 2)
  }

  @Test("Transaction rollback on error")
  func testTransactionRollback() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    do {
      try db.transaction {
        try db.exec("INSERT INTO test (value) VALUES (1)")
        throw LoomError.unsupportedOperation
      }
    } catch {
      // Expected error
    }

    let result = try db.query("SELECT COUNT(*) FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 0)
  }

  @Test("Transaction with deferred mode")
  func testTransactionDeferred() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    try db.transaction(kind: .deferred) {
      try db.exec("INSERT INTO test (value) VALUES (1)")
    }

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 1)
  }

  @Test("Transaction with immediate mode")
  func testTransactionImmediate() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    try db.transaction(kind: .immediate) {
      try db.exec("INSERT INTO test (value) VALUES (1)")
    }

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 1)
  }

  @Test("Transaction with exclusive mode")
  func testTransactionExclusive() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    try db.transaction(kind: .exclusive) {
      try db.exec("INSERT INTO test (value) VALUES (1)")
    }

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 1)
  }

  @Test("Transaction with last inserted row ID")
  func testTransactionWithLastInsertedRowID() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    let insertedId = try db.transaction {
      try db.lastInsertedRowID {
        try db.exec("INSERT INTO test (value) VALUES (42)")
      }
    }

    guard let insertedId else {
      #expect(Bool(false), "No inserted ID returned")
      return
    }

    let result = try db.query("SELECT value FROM test WHERE rowid = \(insertedId)") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 42)
  }

  @Test("Transaction with multiple operations")
  func testTransactionMultipleOperations() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    try db.exec("CREATE TABLE posts (id INTEGER PRIMARY KEY, user_id INTEGER, content TEXT)")

    try db.transaction {
      let userId = try db.lastInsertedRowID {
        try db.exec("INSERT INTO users (name) VALUES ('Alice')")
      }
      try db.exec("INSERT INTO posts (user_id, content) VALUES (\(userId), 'Hello')")
    }

    let result = try db.query(
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

    try db.exec("CREATE TABLE test (value INTEGER)")
    try db.exec("INSERT INTO test (value) VALUES (1)")

    try db.transaction {
      try db.exec("UPDATE test SET value = 2")

      let result = try db.query("SELECT value FROM test") { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }
      #expect(result.first == 2)
    }

    let finalResult = try db.query("SELECT value FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(finalResult.first == 2)
  }

  @Test("Transaction rollback preserves original data")
  func testTransactionRollbackPreservesData() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")
    try db.exec("INSERT INTO test (value) VALUES (1)")

    do {
      try db.transaction {
        try db.exec("UPDATE test SET value = 2")
        try db.exec("INSERT INTO test (value) VALUES (3)")
        throw LoomError.unsupportedOperation
      }
    } catch {
      // Expected error
    }

    let result = try db.query("SELECT value FROM test ORDER BY value") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.count == 1)
    #expect(result.first == 1)
  }

  @Test("Transaction with constraint violation rolls back")
  func testTransactionConstraintViolation() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, value INTEGER)")
    try db.exec("INSERT INTO test (id, value) VALUES (1, 100)")

    do {
      try db.transaction {
        try db.exec("INSERT INTO test (id, value) VALUES (2, 200)")
        // This should violate primary key constraint
        try db.exec("INSERT INTO test (id, value) VALUES (1, 300)")
      }
    } catch {
      // Expected constraint violation
    }

    let result = try db.query("SELECT COUNT(*) FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    // Should only have the original row
    #expect(result.first == 1)
  }
}
