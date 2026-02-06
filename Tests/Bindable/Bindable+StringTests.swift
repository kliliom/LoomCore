import Foundation
import LoomCore
import Testing

@Suite("String Bindable Tests")
@DatabaseActor
struct BindableStringTests {
  @Test("String binding and extraction")
  func testStringBindingAndExtraction() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value TEXT)")

    let testString = "Hello, World!"
    try db.exec("INSERT INTO test (value) VALUES (\(testString))")

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == testString)
  }

  @Test("Empty string binding")
  func testEmptyString() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value TEXT)")
    let emptyString = ""
    try db.exec("INSERT INTO test (value) VALUES (\(emptyString))")

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == "")
  }

  @Test("String with special characters")
  func testStringWithSpecialCharacters() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value TEXT)")

    let specialString = "Test with 'quotes' and \"double quotes\" and newlines\nand tabs\t!"
    try db.exec("INSERT INTO test (value) VALUES (\(specialString))")

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == specialString)
  }

  @Test("String asSQLLiteral")
  func testSQLLiteral() throws {
    let simple = "test"
    #expect(try simple.asSQLLiteral() == "'test'")

    let withQuotes = "test'quote"
    #expect(try withQuotes.asSQLLiteral() == "'test''quote'")
  }

  @Test("String defaultSQLStorageType")
  func testDefaultSQLStorageType() {
    #expect(String.defaultSQLStorageType == "TEXT")
  }

  @Test("String instance methods")
  func testInstanceMethods() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value TEXT)")

    let testValue = "Instance test"
    try db.exec("INSERT INTO test (value) VALUES (\(testValue))")

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == testValue)
  }

  @Test("Unicode string handling")
  func testUnicodeStrings() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value TEXT)")

    let unicodeString = "Hello 世界 🌍 Привет"
    try db.exec("INSERT INTO test (value) VALUES (\(unicodeString))")

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == unicodeString)
  }

  @Test("Multiple strings")
  func testMultipleStrings() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value TEXT)")

    let strings = ["first", "second", "third"]
    for str in strings {
      try db.exec("INSERT INTO test (value) VALUES (\(str))")
    }

    let result = try db.query("SELECT value FROM test ORDER BY rowid") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.count == 3)
    #expect(result == strings)
  }

  @Test("String requiring internal copy")
  func testStringRequiringInternalCopy() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value TEXT)")

    let unicodeString = Array("Hello 世界 🌍 Привет".utf16).withContiguousStorageIfAvailable { ubp in
      ubp.withMemoryRebound(to: UInt16.self) { buffer in
        String(utf16CodeUnits: buffer.baseAddress!, count: buffer.count)
      }
    }

    try db.exec("INSERT INTO test (value) VALUES (\(unicodeString))")

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == unicodeString)
  }
}
