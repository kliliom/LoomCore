import Foundation
import LoomCore
import Testing

@Suite("UUID Bindable Tests")
@DatabaseActor
struct BindableUUIDTests {
  @Test("UUID binding and extraction")
  func testUUIDBinding() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (id BLOB)")

    let testUUID = UUID()
    try db.exec("INSERT INTO test (id) VALUES (\(testUUID))")

    let result = try db.query("SELECT id FROM test") { stmt, _ in
      try UUID.column(of: stmt, at: 0)
    }

    #expect(result.first == testUUID)
  }

  @Test("Multiple UUID values")
  func testMultipleUUIDs() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (id BLOB)")

    let uuid1 = UUID()
    let uuid2 = UUID()
    let uuid3 = UUID()

    try db.exec("INSERT INTO test (id) VALUES (\(uuid1))")
    try db.exec("INSERT INTO test (id) VALUES (\(uuid2))")
    try db.exec("INSERT INTO test (id) VALUES (\(uuid3))")

    let results = try db.query("SELECT id FROM test ORDER BY rowid") { stmt, _ in
      try UUID.column(of: stmt, at: 0)
    }

    #expect(results.count == 3)
    #expect(results[0] == uuid1)
    #expect(results[1] == uuid2)
    #expect(results[2] == uuid3)
  }

  @Test("UUID defaultSQLStorageType")
  func testDefaultSQLStorageType() {
    #expect(UUID.defaultSQLStorageType == "BLOB")
  }

  @Test("UUID as SQL literal")
  func testUUIDAsSQLLiteral() throws {
    let uuid = UUID()
    let literal = try uuid.asSQLLiteral()

    #expect(literal.hasPrefix("X'"))
    #expect(literal.hasSuffix("'"))
    #expect(literal.count == 35)  // X' + 32 hex chars + '
  }

  @Test("Specific UUID value round-trip")
  func testSpecificUUIDValue() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (id BLOB)")

    // Use a specific UUID to verify byte-level accuracy
    let specificUUID = UUID(uuidString: "12345678-1234-5678-1234-567812345678")!
    try db.exec("INSERT INTO test (id) VALUES (\(specificUUID))")

    let result = try db.query("SELECT id FROM test") { stmt, _ in
      try UUID.column(of: stmt, at: 0)
    }

    #expect(result.first == specificUUID)
    #expect(result.first?.uuidString == "12345678-1234-5678-1234-567812345678")
  }

  @Test("UUID as primary key")
  func testUUIDAsPrimaryKey() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (id BLOB PRIMARY KEY, name TEXT)")

    let id = UUID()
    let name = "Test"
    try db.exec("INSERT INTO test (id, name) VALUES (\(id), \(name))")

    let result = try db.query("SELECT id, name FROM test WHERE id = \(id)") { stmt, _ in
      let resultId = try UUID.column(of: stmt, at: 0)
      let resultName = try String.column(of: stmt, at: 1)
      return (resultId, resultName)
    }

    #expect(result.first?.0 == id)
    #expect(result.first?.1 == name)
  }

  @Test("UUID throws unexpectedNullValue for NULL")
  func testUUIDUnexpectedNullValue() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (id BLOB)")
    try db.exec(raw: "INSERT INTO test (id) VALUES (NULL)")

    #expect(throws: LoomError.unexpectedNullValue) {
      try db.query("SELECT id FROM test") { stmt, _ in
        try UUID.column(of: stmt, at: 0)
      }
    }
  }
}
