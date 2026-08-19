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

    try await db.directAccess { dbPtr in
      // Just verify we can access the pointer without crashing
      _ = dbPtr
    }
  }

  @Test("Direct access with sqlite3_last_insert_rowid")
  func testDirectAccessLastInsertRowID() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")
    try await db.exec("INSERT INTO test (value) VALUES (42)")

    let rowID = try await db.directAccess { dbPtr in
      sqlite3_last_insert_rowid(dbPtr)
    }

    #expect(rowID > 0)
  }

  @Test("Direct access with sqlite3_changes")
  func testDirectAccessChanges() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")
    try await db.exec("INSERT INTO test (value) VALUES (1)")
    try await db.exec("INSERT INTO test (value) VALUES (2)")
    try await db.exec("INSERT INTO test (value) VALUES (3)")

    try await db.exec("UPDATE test SET value = 100")

    let changes = try await db.directAccess { dbPtr in
      sqlite3_changes(dbPtr)
    }

    #expect(changes == 3)
  }

  @Test("Direct access with sqlite3_total_changes")
  func testDirectAccessTotalChanges() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")

    for i in 1...5 {
      try await db.exec("INSERT INTO test (value) VALUES (\(i))")
    }

    let totalChanges = try await db.directAccess { dbPtr in
      sqlite3_total_changes(dbPtr)
    }

    #expect(totalChanges >= 5)
  }

  @Test("Direct access with sqlite3_get_autocommit")
  func testDirectAccessAutocommit() async throws {
    let db = try Database.openInMemory()

    let autocommit = try await db.directAccess { dbPtr in
      sqlite3_get_autocommit(dbPtr)
    }

    // Should be in autocommit mode by default
    #expect(autocommit != 0)
  }

  @Test("Direct access in transaction shows no autocommit")
  func testDirectAccessNoAutocommitInTransaction() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")

    try await db.transaction { db in
      let autocommit = try await db.directAccess { dbPtr in
        sqlite3_get_autocommit(dbPtr)
      }

      // Should not be in autocommit mode inside transaction
      #expect(autocommit == 0)

      try await db.exec("INSERT INTO test (value) VALUES (1)")
    }
  }

  @Test("Direct access with sqlite3_db_readonly")
  func testDirectAccessReadonly() async throws {
    let db = try Database.openInMemory()

    let isReadonly = try await db.directAccess { dbPtr in
      sqlite3_db_readonly(dbPtr, "main")
    }

    // In-memory database should not be readonly
    #expect(isReadonly == 0)
  }

  @Test("Direct access with custom pragma")
  func testDirectAccessCustomPragma() async throws {
    let db = try Database.openInMemory()

    // Set a pragma using direct access
    try await db.directAccess { dbPtr in
      var errorMsg: UnsafeMutablePointer<CChar>?
      let result = sqlite3_exec(dbPtr, "PRAGMA foreign_keys = ON", nil, nil, &errorMsg)

      if result != SQLITE_OK {
        if let errorMsg {
          let message = String(cString: errorMsg)
          sqlite3_free(errorMsg)
          throw LoomError.sqlite(result, message: message)
        }
        throw LoomError.sqlite(result, message: "Unknown error")
      }
    }

    // Verify pragma was set
    let result = try await db.query("PRAGMA foreign_keys") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 1)
  }

  @Test("Direct access can throw errors")
  func testDirectAccessCanThrowErrors() async throws {
    let db = try Database.openInMemory()

    await #expect(throws: LoomError.self) {
      try await db.directAccess { dbPtr in
        var errorMsg: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(dbPtr, "INVALID SQL", nil, nil, &errorMsg)

        if result != SQLITE_OK {
          if let errorMsg {
            let message = String(cString: errorMsg)
            sqlite3_free(errorMsg)
            throw LoomError.sqlite(result, message: message)
          }
          throw LoomError.sqlite(result, message: "Unknown error")
        }
      }
    }
  }

  @Test("Direct access returns value from block")
  func testDirectAccessReturnsValue() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")
    try await db.exec("INSERT INTO test (value) VALUES (42)")

    let value = try await db.directAccess { dbPtr -> Int64 in
      sqlite3_last_insert_rowid(dbPtr)
    }

    #expect(value > 0)
  }

  @Test("Direct access with sqlite3_db_filename")
  func testDirectAccessDbFilename() async throws {
    let db = try Database.openInMemory()

    let filename = try await db.directAccess { dbPtr -> String? in
      if let cStr = sqlite3_db_filename(dbPtr, "main") {
        return String(cString: cStr)
      }
      return nil
    }

    // In-memory database should return nil or empty
    #expect(filename == nil || filename == "")
  }
}
