import Foundation
import Testing

@testable import LoomCore

@Suite("Database Cached Tests")
@DatabaseActor
struct DatabaseCachedTests {
  @Test("Cached block enables statement caching")
  func testCachedBlockEnablesCaching() async throws {
    let db = try Database.openInMemory()
    #expect(db.handle.resourceStore.statementCache.count == 0)

    try db.exec("CREATE TABLE test (value INTEGER)")

    // Execute statements within cached block
    try db.cached {
      for i in 1...10 {
        try db.exec("INSERT INTO test (value) VALUES (\(i))")
      }
    }
    #expect(db.handle.resourceStore.statementCache.count == 1)

    let result = try db.query("SELECT COUNT(*) FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 10)
  }

  @Test("Cached block reuses prepared statements")
  func testCachedBlockReusesStatements() async throws {
    let db = try Database.openInMemory()
    #expect(db.handle.resourceStore.statementCache.count == 0)

    try db.exec("CREATE TABLE test (value TEXT)")

    // Multiple executions of the same SQL should reuse cached statement
    try db.cached {
      try db.exec("INSERT INTO test (value) VALUES (\("first"))")
      try db.exec("INSERT INTO test (value) VALUES (\("second"))")
      try db.exec("INSERT INTO test (value) VALUES (\("third"))")
    }
    #expect(db.handle.resourceStore.statementCache.count == 1)

    let result = try db.query("SELECT value FROM test ORDER BY rowid") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.count == 3)
    #expect(result == ["first", "second", "third"])
  }

  @Test("Nested cached blocks share same cache")
  func testNestedCachedBlocks() async throws {
    let db = try Database.openInMemory()
    #expect(db.handle.resourceStore.statementCache.count == 0)

    try db.exec("CREATE TABLE test (value INTEGER)")

    try db.cached {
      try db.exec("INSERT INTO test (value) VALUES (\(1))")

      try db.cached {
        // Inner cached block should work with same cache
        try db.exec("INSERT INTO test (value) VALUES (\(2))")
      }

      try db.exec("INSERT INTO test (value) VALUES (\(3))")
    }
    #expect(db.handle.resourceStore.statementCache.count == 1)

    let result = try db.query("SELECT value FROM test ORDER BY value") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result == [1, 2, 3])
  }

  @Test("Cached block with query operations")
  func testCachedBlockWithQueries() async throws {
    let db = try Database.openInMemory()
    #expect(db.handle.resourceStore.statementCache.count == 0)

    try db.exec("CREATE TABLE test (id INTEGER, value TEXT)")
    try db.exec("INSERT INTO test (id, value) VALUES (1, 'one')")
    try db.exec("INSERT INTO test (id, value) VALUES (2, 'two')")
    try db.exec("INSERT INTO test (id, value) VALUES (3, 'three')")

    let results = try db.cached {
      var output: [String] = []

      for i in 1...3 {
        let result = try db.query("SELECT value FROM test WHERE id = \(i)") { stmt, _ in
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

    try db.exec("CREATE TABLE test (value INTEGER)")

    try db.cached {
      // Insert
      try db.exec("INSERT INTO test (value) VALUES (100)")

      // Query
      let result1 = try db.query("SELECT value FROM test") { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }
      #expect(result1.first == 100)

      // Update
      try db.exec("UPDATE test SET value = 200 WHERE value = 100")

      // Query again
      let result2 = try db.query("SELECT value FROM test") { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }
      #expect(result2.first == 200)
    }
  }

  @Test("Cached block returns value")
  func testCachedBlockReturnsValue() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")
    try db.exec("INSERT INTO test (value) VALUES (42)")

    let result = try db.cached {
      try db.query("SELECT value FROM test") { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }.first
    }

    #expect(result == 42)
  }

  @Test("Cached block with batch inserts")
  func testCachedBlockWithBatchInserts() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (id INTEGER, name TEXT)")

    let names = ["Alice", "Bob", "Charlie", "David", "Eve"]

    try db.cached {
      for (index, name) in names.enumerated() {
        try db.exec("INSERT INTO test (id, name) VALUES (\(index + 1), \(name))")
      }
    }

    let result = try db.query("SELECT name FROM test ORDER BY id") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result == names)
  }

  @Test("Cached block with errors still throws")
  func testCachedBlockWithErrors() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    #expect(throws: LoomError.self) {
      try db.cached {
        try db.exec("INSERT INTO test (value) VALUES (1)")
        try db.exec("INVALID SQL STATEMENT")
      }
    }
  }

  @Test("Multiple cached blocks use same scopes")
  func testMultipleCachedBlocksSameScopes() async throws {
    let db = try Database.openInMemory()
    #expect(db.handle.resourceStore.statementCache.count == 0)

    try db.exec("CREATE TABLE test (value INTEGER)")

    // First cached block
    try db.cached {
      try db.exec("INSERT INTO test (value) VALUES (\(1))")
      try db.exec("INSERT INTO test (value) VALUES (\(2))")
    }

    // Second cached block
    try db.cached {
      try db.exec("INSERT INTO test (value) VALUES (\(3))")
      try db.exec("INSERT INTO test (value) VALUES (\(4))")
    }

    #expect(db.handle.resourceStore.statementCache.count == 1)
    let result = try db.query("SELECT COUNT(*) FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 4)
  }
}
