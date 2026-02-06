import Foundation
import LoomCore
import SQLite3
import Testing

@Suite("Database Last Inserted Row ID Tests")
@DatabaseActor
struct DatabaseLastInsertedRowIDTests {
  @Test("Last inserted row ID captures single insert")
  func testLastInsertedRowIDSingleInsert() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    let rowID = try db.lastInsertedRowID {
      try db.exec("INSERT INTO test (value) VALUES (42)")
    }

    #expect(rowID != nil)
    #expect(rowID! > 0)
  }

  @Test("Last inserted row ID with multiple inserts returns last")
  func testLastInsertedRowIDMultipleInserts() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    let rowID = try db.lastInsertedRowID {
      try db.exec("INSERT INTO test (value) VALUES (1)")
      let firstID = try db.directAccess { sqlite3_last_insert_rowid($0) }

      try db.exec("INSERT INTO test (value) VALUES (2)")
      let secondID = try db.directAccess { sqlite3_last_insert_rowid($0) }

      // Verify IDs are incrementing
      #expect(secondID > firstID)
    }

    #expect(rowID != nil)
  }

  @Test("Last inserted row ID returns nil when no insert")
  func testLastInsertedRowIDNoInsert() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    let rowID = try db.lastInsertedRowID {
      // No INSERT statement
      try db.exec("SELECT * FROM test")
    }

    #expect(rowID == nil)
  }

  @Test("Last inserted row ID with explicit primary key")
  func testLastInsertedRowIDExplicitPrimaryKey() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, value TEXT)")

    let rowID = try db.lastInsertedRowID {
      try db.exec("INSERT INTO test (id, value) VALUES (100, 'test')")
    }

    #expect(rowID == 100)
  }

  @Test("Last inserted row ID resets before block")
  func testLastInsertedRowIDResets() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    // First insert outside the block
    try db.exec("INSERT INTO test (value) VALUES (1)")

    // This should return nil because the block doesn't insert anything
    let rowID = try db.lastInsertedRowID {
      // Just run a non-insert operation (UPDATE with no matching rows)
      try db.exec("UPDATE test SET value = 2 WHERE value = 999")
    }

    #expect(rowID == nil)
  }

  @Test("Last inserted row ID in transaction")
  func testLastInsertedRowIDInTransaction() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    let rowID = try db.transaction {
      try db.lastInsertedRowID {
        try db.exec("INSERT INTO test (value) VALUES (42)")
      }
    }

    #expect(rowID != nil)
    #expect(rowID! > 0)
  }

  @Test("Last inserted row ID with string value")
  func testLastInsertedRowIDWithStringValue() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value TEXT)")

    let rowID = try db.lastInsertedRowID {
      try db.exec("INSERT INTO test (value) VALUES ('hello')")
    }

    #expect(rowID != nil)
    #expect(rowID! > 0)
  }

  @Test("Last inserted row ID with multiple columns")
  func testLastInsertedRowIDMultipleColumns() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (name TEXT, age INTEGER, email TEXT)")

    let rowID = try db.lastInsertedRowID {
      try db.exec("INSERT INTO test (name, age, email) VALUES ('Alice', 25, 'alice@example.com')")
    }

    #expect(rowID != nil)

    // Verify we can query using the row ID
    let result = try db.query("SELECT name FROM test WHERE rowid = \(rowID!)") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == "Alice")
  }

  @Test("Last inserted row ID with UPDATE returns nil")
  func testLastInsertedRowIDWithUpdate() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")
    try db.exec("INSERT INTO test (value) VALUES (1)")

    let rowID = try db.lastInsertedRowID {
      try db.exec("UPDATE test SET value = 2")
    }

    #expect(rowID == nil)
  }

  @Test("Last inserted row ID with DELETE returns nil")
  func testLastInsertedRowIDWithDelete() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")
    try db.exec("INSERT INTO test (value) VALUES (1)")

    let rowID = try db.lastInsertedRowID {
      try db.exec("DELETE FROM test WHERE value = 1")
    }

    #expect(rowID == nil)
  }

  @Test("Last inserted row ID with error still throws")
  func testLastInsertedRowIDWithError() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    #expect(throws: LoomError.self) {
      try db.lastInsertedRowID {
        try db.exec("INSERT INTO test (value) VALUES (1)")
        try db.exec("INVALID SQL")
      }
    }
  }

  @Test("Last inserted row ID with batch inserts")
  func testLastInsertedRowIDBatchInserts() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (name TEXT)")

    let names = ["Alice", "Bob", "Charlie"]
    var lastRowID: Int64?

    for name in names {
      lastRowID = try db.lastInsertedRowID {
        try db.exec("INSERT INTO test (name) VALUES (\(name))")
      }
    }

    #expect(lastRowID != nil)

    // Verify all rows were inserted
    let count = try db.query("SELECT COUNT(*) FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(count.first == 3)
  }

  @Test("Last inserted row ID with AUTOINCREMENT")
  func testLastInsertedRowIDAutoincrement() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY AUTOINCREMENT, value TEXT)")

    let rowID1 = try db.lastInsertedRowID {
      try db.exec("INSERT INTO test (value) VALUES ('first')")
    }

    let rowID2 = try db.lastInsertedRowID {
      try db.exec("INSERT INTO test (value) VALUES ('second')")
    }

    #expect(rowID1 != nil)
    #expect(rowID2 != nil)
    #expect(rowID2! > rowID1!)
  }
}
