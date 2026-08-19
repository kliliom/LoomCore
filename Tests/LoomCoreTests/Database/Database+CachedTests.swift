import Foundation
import Testing

@testable import LoomCore

@Suite("Database Cached Tests")
@DatabaseActor
struct DatabaseCachedTests {
  // Reentrant use of the same SQL (a query issued from inside another query's
  // stepper) is no longer expressible: steppers are synchronous and every
  // operation runs to completion on the actor before the next one starts, so
  // two live handles can never share one cached statement. This test keeps the
  // observable half of that guarantee — back-to-back queries with the identical
  // SQL string each iterate a full, correct result set.
  @Test("Repeated queries on the same SQL inside a cached block each see every row")
  func testRepeatedSameSQLInsideCachedBlock() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")
    try await db.exec("INSERT INTO t (value) VALUES (10)")
    try await db.exec("INSERT INTO t (value) VALUES (20)")

    let sql: SQLStatement = "SELECT value FROM t ORDER BY value"

    let (first, second) = try await db.cached {
      let first = try await db.query(sql) { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }
      let second = try await db.query(sql) { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }
      return (first, second)
    }

    #expect(first == [10, 20])
    #expect(second == [10, 20])
  }

  @Test("Cached block enables statement caching")
  func testCachedBlockEnablesCaching() async throws {
    let db = try Database.openInMemory()
    #expect(db.handle.resourceStore.statementCache.count == 0)

    try await db.exec("CREATE TABLE test (value INTEGER)")

    // Execute statements within cached block
    try await db.cached {
      for i in 1...10 {
        try await db.exec("INSERT INTO test (value) VALUES (\(i))")
      }
    }
    #expect(db.handle.resourceStore.statementCache.count == 1)

    let result = try await db.query("SELECT COUNT(*) FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 10)
  }

  @Test("Cached block reuses prepared statements")
  func testCachedBlockReusesStatements() async throws {
    let db = try Database.openInMemory()
    #expect(db.handle.resourceStore.statementCache.count == 0)

    try await db.exec("CREATE TABLE test (value TEXT)")

    // Multiple executions of the same SQL should reuse cached statement
    try await db.cached {
      try await db.exec("INSERT INTO test (value) VALUES (\("first"))")
      try await db.exec("INSERT INTO test (value) VALUES (\("second"))")
      try await db.exec("INSERT INTO test (value) VALUES (\("third"))")
    }
    #expect(db.handle.resourceStore.statementCache.count == 1)

    let result = try await db.query("SELECT value FROM test ORDER BY rowid") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.count == 3)
    #expect(result == ["first", "second", "third"])
  }

  @Test("Nested cached blocks share same cache")
  func testNestedCachedBlocks() async throws {
    let db = try Database.openInMemory()
    #expect(db.handle.resourceStore.statementCache.count == 0)

    try await db.exec("CREATE TABLE test (value INTEGER)")

    try await db.cached {
      try await db.exec("INSERT INTO test (value) VALUES (\(1))")

      try await db.cached {
        // Inner cached block should work with same cache
        try await db.exec("INSERT INTO test (value) VALUES (\(2))")
      }

      try await db.exec("INSERT INTO test (value) VALUES (\(3))")
    }
    #expect(db.handle.resourceStore.statementCache.count == 1)

    let result = try await db.query("SELECT value FROM test ORDER BY value") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result == [1, 2, 3])
  }

  @Test("Cached block with query operations")
  func testCachedBlockWithQueries() async throws {
    let db = try Database.openInMemory()
    #expect(db.handle.resourceStore.statementCache.count == 0)

    try await db.exec("CREATE TABLE test (id INTEGER, value TEXT)")
    try await db.exec("INSERT INTO test (id, value) VALUES (1, 'one')")
    try await db.exec("INSERT INTO test (id, value) VALUES (2, 'two')")
    try await db.exec("INSERT INTO test (id, value) VALUES (3, 'three')")

    let results = try await db.cached {
      var output: [String] = []

      for i in 1...3 {
        let result = try await db.query("SELECT value FROM test WHERE id = \(i)") { stmt, _ in
          try String.column(of: stmt, at: 0)
        }
        if let value = result.first {
          output.append(value)
        }
      }

      return output
    }
    #expect(db.handle.resourceStore.statementCache.count == 1)

    #expect(results.count == 3)
    #expect(results == ["one", "two", "three"])
  }

  @Test("Cached block with mixed operations")
  func testCachedBlockWithMixedOperations() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")

    try await db.cached {
      // Insert
      try await db.exec("INSERT INTO test (value) VALUES (100)")

      // Query
      let result1 = try await db.query("SELECT value FROM test") { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }
      #expect(result1.first == 100)

      // Update
      try await db.exec("UPDATE test SET value = 200 WHERE value = 100")

      // Query again
      let result2 = try await db.query("SELECT value FROM test") { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }
      #expect(result2.first == 200)
    }
  }

  @Test("Cached block returns value")
  func testCachedBlockReturnsValue() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")
    try await db.exec("INSERT INTO test (value) VALUES (42)")

    let result = try await db.cached {
      try await db.query("SELECT value FROM test") { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }.first
    }

    #expect(result == 42)
  }

  @Test("Cached block with batch inserts")
  func testCachedBlockWithBatchInserts() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (id INTEGER, name TEXT)")

    let names = ["Alice", "Bob", "Charlie", "David", "Eve"]

    try await db.cached {
      for (index, name) in names.enumerated() {
        try await db.exec("INSERT INTO test (id, name) VALUES (\(index + 1), \(name))")
      }
    }

    let result = try await db.query("SELECT name FROM test ORDER BY id") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result == names)
  }

  @Test("Cached block with errors still throws")
  func testCachedBlockWithErrors() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")

    await #expect(throws: LoomError.self) {
      try await db.cached {
        try await db.exec("INSERT INTO test (value) VALUES (1)")
        try await db.exec("INVALID SQL STATEMENT")
      }
    }
  }

  @Test("Multiple cached blocks use same scopes")
  func testMultipleCachedBlocksSameScopes() async throws {
    let db = try Database.openInMemory()
    #expect(db.handle.resourceStore.statementCache.count == 0)

    try await db.exec("CREATE TABLE test (value INTEGER)")

    // First cached block
    try await db.cached {
      try await db.exec("INSERT INTO test (value) VALUES (\(1))")
      try await db.exec("INSERT INTO test (value) VALUES (\(2))")
    }

    // Second cached block
    try await db.cached {
      try await db.exec("INSERT INTO test (value) VALUES (\(3))")
      try await db.exec("INSERT INTO test (value) VALUES (\(4))")
    }

    #expect(db.handle.resourceStore.statementCache.count == 1)
    let result = try await db.query("SELECT COUNT(*) FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 4)
  }
}
