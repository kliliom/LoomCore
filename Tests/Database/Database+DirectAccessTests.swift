import Foundation
import LoomCore
import SQLite3
import Testing

@Suite("Database Direct Access Tests")
@DatabaseActor
struct DatabaseDirectAccessTests {
  @Test("Direct access provides database pointer")
  func testDirectAccessProvidesPointer() async throws {
    let db = try Database.openInMemory()

    try db.directAccess { dbPtr in
      // Just verify we can access the pointer without crashing
      _ = dbPtr
    }
  }

  @Test("Direct access with sqlite3_last_insert_rowid")
  func testDirectAccessLastInsertRowID() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")
    try db.exec("INSERT INTO test (value) VALUES (42)")

    let rowID = try db.directAccess { dbPtr in
      sqlite3_last_insert_rowid(dbPtr)
    }

    #expect(rowID > 0)
  }

  @Test("Direct access with sqlite3_changes")
  func testDirectAccessChanges() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")
    try db.exec("INSERT INTO test (value) VALUES (1)")
    try db.exec("INSERT INTO test (value) VALUES (2)")
    try db.exec("INSERT INTO test (value) VALUES (3)")

    try db.exec("UPDATE test SET value = 100")

    let changes = try db.directAccess { dbPtr in
      sqlite3_changes(dbPtr)
    }

    #expect(changes == 3)
  }

  @Test("Direct access with sqlite3_total_changes")
  func testDirectAccessTotalChanges() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    for i in 1...5 {
      try db.exec("INSERT INTO test (value) VALUES (\(i))")
    }

    let totalChanges = try db.directAccess { dbPtr in
      sqlite3_total_changes(dbPtr)
    }

    #expect(totalChanges >= 5)
  }

  @Test("Direct access with sqlite3_get_autocommit")
  func testDirectAccessAutocommit() async throws {
    let db = try Database.openInMemory()

    let autocommit = try db.directAccess { dbPtr in
      sqlite3_get_autocommit(dbPtr)
    }

    // Should be in autocommit mode by default
    #expect(autocommit != 0)
  }

  @Test("Direct access in transaction shows no autocommit")
  func testDirectAccessNoAutocommitInTransaction() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    try db.transaction {
      let autocommit = try db.directAccess { dbPtr in
        sqlite3_get_autocommit(dbPtr)
      }

      // Should not be in autocommit mode inside transaction
      #expect(autocommit == 0)

      try db.exec("INSERT INTO test (value) VALUES (1)")
    }
  }

  @Test("Direct access with sqlite3_db_readonly")
  func testDirectAccessReadonly() async throws {
    let db = try Database.openInMemory()

    let isReadonly = try db.directAccess { dbPtr in
      sqlite3_db_readonly(dbPtr, "main")
    }

    // In-memory database should not be readonly
    #expect(isReadonly == 0)
  }

  @Test("Direct access with custom pragma")
  func testDirectAccessCustomPragma() async throws {
    let db = try Database.openInMemory()

    // Set a pragma using direct access
    try db.directAccess { dbPtr in
      var errorMsg: UnsafeMutablePointer<CChar>?
      let result = sqlite3_exec(dbPtr, "PRAGMA foreign_keys = ON", nil, nil, &errorMsg)

      if result != SQLITE_OK {
        if let errorMsg {
          let message = String(cString: errorMsg)
          sqlite3_free(errorMsg)
          throw LoomError(sqlite: result, message: message)
        }
        throw LoomError(sqlite: result, message: "Unknown error")
      }
    }

    // Verify pragma was set
    let result = try db.query("PRAGMA foreign_keys") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 1)
  }

  @Test("Direct access can throw errors")
  func testDirectAccessCanThrowErrors() async throws {
    let db = try Database.openInMemory()

    #expect(throws: LoomError.self) {
      try db.directAccess { dbPtr in
        var errorMsg: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(dbPtr, "INVALID SQL", nil, nil, &errorMsg)

        if result != SQLITE_OK {
          if let errorMsg {
            let message = String(cString: errorMsg)
            sqlite3_free(errorMsg)
            throw LoomError(sqlite: result, message: message)
          }
          throw LoomError(sqlite: result, message: "Unknown error")
        }
      }
    }
  }

  @Test("Direct access returns value from block")
  func testDirectAccessReturnsValue() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")
    try db.exec("INSERT INTO test (value) VALUES (42)")

    let value = try db.directAccess { dbPtr -> Int64 in
      sqlite3_last_insert_rowid(dbPtr)
    }

    #expect(value > 0)
  }

  @Test("Direct access with sqlite3_db_filename")
  func testDirectAccessDbFilename() async throws {
    let db = try Database.openInMemory()

    let filename = try db.directAccess { dbPtr -> String? in
      if let cStr = sqlite3_db_filename(dbPtr, "main") {
        return String(cString: cStr)
      }
      return nil
    }

    // In-memory database should return nil or empty
    #expect(filename == nil || filename == "")
  }
}
