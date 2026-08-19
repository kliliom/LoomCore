import Foundation
import LoomCore
import Testing

@Suite("Array Bindable Tests")
@DatabaseActor
struct BindableArrayTests {
  @Test("String array binding and extraction")
  func testStringArrayBinding() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data BLOB)")

    let tags = ["swift", "database", "testing"]
    try await db.exec("INSERT INTO test (data) VALUES (\(tags))")

    let result = try await db.query("SELECT data FROM test") { stmt, _ in
      try [String].column(of: stmt, at: 0)
    }

    #expect(result.first == tags)
  }

  @Test("Int array binding and extraction")
  func testIntArrayBinding() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data BLOB)")

    let numbers = [1, 2, 3, 4, 5]
    try await db.exec("INSERT INTO test (data) VALUES (\(numbers))")

    let result = try await db.query("SELECT data FROM test") { stmt, _ in
      try [Int].column(of: stmt, at: 0)
    }

    #expect(result.first == numbers)
  }

  @Test("Empty array")
  func testEmptyArray() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data BLOB)")

    let empty: [String] = []
    try await db.exec("INSERT INTO test (data) VALUES (\(empty))")

    let result = try await db.query("SELECT data FROM test") { stmt, _ in
      try [String].column(of: stmt, at: 0)
    }

    #expect(result.first?.isEmpty == true)
  }

  @Test("Array with Codable elements")
  func testArrayWithCodableElements() async throws {
    struct Point: Codable, JSONBindable, Equatable {
      let x: Int
      let y: Int
    }

    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data BLOB)")

    let points = [
      Point(x: 1, y: 2),
      Point(x: 3, y: 4),
      Point(x: 5, y: 6),
    ]
    try await db.exec("INSERT INTO test (data) VALUES (\(points))")

    let result = try await db.query("SELECT data FROM test") { stmt, _ in
      try [Point].column(of: stmt, at: 0)
    }

    #expect(result.first == points)
  }

  @Test("Array as SQL literal")
  func testArrayAsSQLLiteral() async throws {
    let tags = ["swift", "database"]
    let literal = try tags.asSQLLiteral()

    #expect(literal == #"'["swift","database"]'"#)
  }

  @Test("Array defaultSQLStorageType")
  func testArrayDefaultSQLStorageType() {
    #expect([String].defaultSQLStorageType == "TEXT")
    #expect([Int].defaultSQLStorageType == "TEXT")
  }

  @Test("Large array")
  func testLargeArray() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data BLOB)")

    let largeArray = Array(1...100)
    try await db.exec("INSERT INTO test (data) VALUES (\(largeArray))")

    let result = try await db.query("SELECT data FROM test") { stmt, _ in
      try [Int].column(of: stmt, at: 0)
    }

    #expect(result.first?.count == 100)
    #expect(result.first == largeArray)
  }

  @Test("Optional array")
  func testOptionalArray() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data BLOB)")

    let array1: [String]? = ["a", "b", "c"]
    let array2: [String]? = nil

    try await db.exec("INSERT INTO test (data) VALUES (\(array1))")
    try await db.exec("INSERT INTO test (data) VALUES (\(array2))")

    let result = try await db.query("SELECT data FROM test ORDER BY rowid") { stmt, _ in
      try Optional<[String]>.column(of: stmt, at: 0)
    }

    #expect(result.count == 2)
    #expect(result[0] == ["a", "b", "c"])
    #expect(result[1] == nil)
  }

  @Test("Array with mixed string lengths")
  func testArrayWithMixedStringLengths() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data BLOB)")

    let strings = [
      "short",
      "a much longer string with many characters",
      "",
      "medium length",
    ]
    try await db.exec("INSERT INTO test (data) VALUES (\(strings))")

    let result = try await db.query("SELECT data FROM test") { stmt, _ in
      try [String].column(of: stmt, at: 0)
    }

    #expect(result.first == strings)
  }
}
