import Foundation
import LoomCore
import Testing

@Suite("String Bindable Tests")
@DatabaseActor
struct BindableStringTests {
  @Test("String binding and extraction")
  func testStringBindingAndExtraction() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value TEXT)")

    let testString = "Hello, World!"
    try await db.exec("INSERT INTO test (value) VALUES (\(testString))")

    let result = try await db.query("SELECT value FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == testString)
  }

  @Test("Empty string binding")
  func testEmptyString() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value TEXT)")
    let emptyString = ""
    try await db.exec("INSERT INTO test (value) VALUES (\(emptyString))")

    let result = try await db.query("SELECT value FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == "")
  }

  @Test("String with special characters")
  func testStringWithSpecialCharacters() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value TEXT)")

    let specialString = "Test with 'quotes' and \"double quotes\" and newlines\nand tabs\t!"
    try await db.exec("INSERT INTO test (value) VALUES (\(specialString))")

    let result = try await db.query("SELECT value FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == specialString)
  }

  @Test("String asSQLLiteral")
  func testSQLLiteral() async throws {
    let simple = "test"
    #expect(try simple.asSQLLiteral() == "'test'")

    let withQuotes = "test'quote"
    #expect(try withQuotes.asSQLLiteral() == "'test''quote'")

    // Grapheme-level search would see `'` + U+0301 as a single character and skip the
    // quote; escaping must operate on Unicode scalars.
    let withCombiningScalar = "a'\u{301}b"
    #expect(try withCombiningScalar.asSQLLiteral() == "'a''\u{301}b'")
  }

  @Test("String defaultSQLStorageType")
  func testDefaultSQLStorageType() {
    #expect(String.defaultSQLStorageType == "TEXT")
  }

  @Test("String instance methods")
  func testInstanceMethods() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value TEXT)")

    let testValue = "Instance test"
    try await db.exec("INSERT INTO test (value) VALUES (\(testValue))")

    let result = try await db.query("SELECT value FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == testValue)
  }

  @Test("Unicode string handling")
  func testUnicodeStrings() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value TEXT)")

    let unicodeString = "Hello 世界 🌍 Привет"
    try await db.exec("INSERT INTO test (value) VALUES (\(unicodeString))")

    let result = try await db.query("SELECT value FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == unicodeString)
  }

  @Test("Multiple strings")
  func testMultipleStrings() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value TEXT)")

    let strings = ["first", "second", "third"]
    for str in strings {
      try await db.exec("INSERT INTO test (value) VALUES (\(str))")
    }

    let result = try await db.query("SELECT value FROM test ORDER BY rowid") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.count == 3)
    #expect(result == strings)
  }

  @Test("String requiring internal copy")
  func testStringRequiringInternalCopy() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value TEXT)")

    let unicodeString = Array("Hello 世界 🌍 Привет".utf16).withContiguousStorageIfAvailable { ubp in
      ubp.withMemoryRebound(to: UInt16.self) { buffer in
        String(utf16CodeUnits: buffer.baseAddress!, count: buffer.count)
      }
    }

    try await db.exec("INSERT INTO test (value) VALUES (\(unicodeString))")

    let result = try await db.query("SELECT value FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == unicodeString)
  }

  @Test("String with embedded NUL bytes round-trips intact")
  func testStringWithEmbeddedNulBytes() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value TEXT)")

    let value = "abc\0def"
    try await db.exec("INSERT INTO test (value) VALUES (\(value))")

    let result = try await db.query("SELECT value FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == value)
    #expect(result.first?.utf8.count == 7)
  }

  @Test("String bind throws with connection error message on out-of-range index")
  func testStringBindOutOfRangeIndex() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE test (value TEXT)")

    let error = await #expect(throws: LoomError.self) {
      try await db.exec(
        raw: "INSERT INTO test (value) VALUES (?)",
        binder: { stmt in
          try String.bind(to: stmt, value: "hello", at: 99)
        }
      )
    }
    let message = try #require(error?.message)
    #expect(!message.isEmpty)
  }
}
