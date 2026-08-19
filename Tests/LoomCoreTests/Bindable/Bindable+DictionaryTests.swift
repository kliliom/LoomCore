import Foundation
import LoomCore
import Testing

@Suite("Dictionary Bindable Tests")
@DatabaseActor
struct BindableDictionaryTests {
  @Test("String to String dictionary binding and extraction")
  func testStringDictionaryBinding() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data BLOB)")

    let dict = ["name": "Alice", "city": "Springfield", "country": "USA"]
    try await db.exec("INSERT INTO test (data) VALUES (\(dict))")

    let result = try await db.query("SELECT data FROM test") { stmt, _ in
      try [String: String].column(of: stmt, at: 0)
    }

    #expect(result.first == dict)
  }

  @Test("String to Int dictionary binding and extraction")
  func testStringIntDictionaryBinding() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data BLOB)")

    let scores = ["math": 95, "science": 88, "history": 92]
    try await db.exec("INSERT INTO test (data) VALUES (\(scores))")

    let result = try await db.query("SELECT data FROM test") { stmt, _ in
      try [String: Int].column(of: stmt, at: 0)
    }

    #expect(result.first == scores)
  }

  @Test("Empty dictionary")
  func testEmptyDictionary() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data BLOB)")

    let empty: [String: String] = [:]
    try await db.exec("INSERT INTO test (data) VALUES (\(empty))")

    let result = try await db.query("SELECT data FROM test") { stmt, _ in
      try [String: String].column(of: stmt, at: 0)
    }

    #expect(result.first?.isEmpty == true)
  }

  @Test("Dictionary with Codable values")
  func testDictionaryWithCodableValues() async throws {
    struct Config: Codable, Bindable, Equatable {
      let enabled: Bool
      let timeout: Int
    }

    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data BLOB)")

    let settings = [
      "api": Config(enabled: true, timeout: 30),
      "cache": Config(enabled: false, timeout: 60),
    ]
    try await db.exec("INSERT INTO test (data) VALUES (\(settings))")

    let result = try await db.query("SELECT data FROM test") { stmt, _ in
      try [String: Config].column(of: stmt, at: 0)
    }

    #expect(result.first == settings)
  }

  @Test("Dictionary as SQL literal")
  func testDictionaryAsSQLLiteral() async throws {
    let dict = ["key": "value"]
    let literal = try dict.asSQLLiteral()

    #expect(literal.hasPrefix("X'"))
    #expect(literal.hasSuffix("'"))
  }

  @Test("Dictionary defaultSQLStorageType")
  func testDictionaryDefaultSQLStorageType() {
    #expect([String: String].defaultSQLStorageType == "BLOB")
    #expect([String: Int].defaultSQLStorageType == "BLOB")
  }

  @Test("Large dictionary")
  func testLargeDictionary() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data BLOB)")

    var largeDict: [String: Int] = [:]
    for i in 1...50 {
      largeDict["key\(i)"] = i
    }
    try await db.exec("INSERT INTO test (data) VALUES (\(largeDict))")

    let result = try await db.query("SELECT data FROM test") { stmt, _ in
      try [String: Int].column(of: stmt, at: 0)
    }

    #expect(result.first?.count == 50)
    #expect(result.first == largeDict)
  }

  @Test("Optional dictionary")
  func testOptionalDictionary() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data BLOB)")

    let dict1: [String: String]? = ["a": "1", "b": "2"]
    let dict2: [String: String]? = nil

    try await db.exec("INSERT INTO test (data) VALUES (\(dict1))")
    try await db.exec("INSERT INTO test (data) VALUES (\(dict2))")

    let result = try await db.query("SELECT data FROM test ORDER BY rowid") { stmt, _ in
      try Optional<[String: String]>.column(of: stmt, at: 0)
    }

    #expect(result.count == 2)
    #expect(result[0] == ["a": "1", "b": "2"])
    #expect(result[1] == nil)
  }

  @Test("Dictionary with special characters in keys and values")
  func testDictionaryWithSpecialCharacters() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data BLOB)")

    let dict = [
      "key with spaces": "value with spaces",
      "key'with'quotes": "value\"with\"quotes",
      "unicode_😀": "emoji_🎉",
    ]
    try await db.exec("INSERT INTO test (data) VALUES (\(dict))")

    let result = try await db.query("SELECT data FROM test") { stmt, _ in
      try [String: String].column(of: stmt, at: 0)
    }

    #expect(result.first == dict)
  }

  @Test("Nested dictionary structure")
  func testNestedDictionaryStructure() async throws {
    struct Metadata: Codable, Bindable, Equatable {
      let tags: [String]
      let version: Int
    }

    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data BLOB)")

    let data = [
      "config": Metadata(tags: ["prod", "v1"], version: 1),
      "backup": Metadata(tags: ["test", "v2"], version: 2),
    ]
    try await db.exec("INSERT INTO test (data) VALUES (\(data))")

    let result = try await db.query("SELECT data FROM test") { stmt, _ in
      try [String: Metadata].column(of: stmt, at: 0)
    }

    #expect(result.first == data)
  }
}
