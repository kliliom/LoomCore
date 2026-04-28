import Foundation
import LoomCore
import Testing

@Suite("Optional Bindable Tests")
@DatabaseActor
struct BindableOptionalTests {
  @Test("Optional String with value")
  func testOptionalStringWithValue() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value TEXT)")

    let testValue: String? = "Hello"
    try db.exec("INSERT INTO test (value) VALUES (\(testValue))")

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try Optional<String>.column(of: stmt, at: 0)
    }

    #expect(result.first == testValue)
  }

  @Test("Optional String with nil")
  func testOptionalStringWithNil() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value TEXT)")

    let testValue: String? = nil
    try db.exec("INSERT INTO test (value) VALUES (\(testValue))")

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try Optional<String>.column(of: stmt, at: 0)
    }

    #expect(result == [nil])
  }

  @Test("Optional Int with value")
  func testOptionalIntWithValue() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    let testValue: Int? = 42
    try db.exec("INSERT INTO test (value) VALUES (\(testValue))")

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try Optional<Int>.column(of: stmt, at: 0)
    }

    #expect(result.first == testValue)
  }

  @Test("Optional Int with nil")
  func testOptionalIntWithNil() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    let testValue: Int? = nil
    try db.exec("INSERT INTO test (value) VALUES (\(testValue))")

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try Optional<Int>.column(of: stmt, at: 0)
    }

    #expect(result == [nil])
  }

  @Test("Optional Double with value and nil")
  func testOptionalDouble() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value DOUBLE)")

    let value1: Double? = 3.14
    try db.exec("INSERT INTO test (value) VALUES (\(value1))")

    let result1 = try db.query("SELECT value FROM test LIMIT 1") { stmt, _ in
      try Optional<Double>.column(of: stmt, at: 0)
    }
    #expect(result1.first == value1)

    try db.exec("DELETE FROM test")
    let value2: Double? = nil
    try db.exec("INSERT INTO test (value) VALUES (\(value2))")

    let result2 = try db.query("SELECT value FROM test") { stmt, _ in
      try Optional<Double>.column(of: stmt, at: 0)
    }
    #expect(result2 == [nil])
  }

  @Test("Optional Bool binding")
  func testOptionalBool() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value BOOLEAN)")

    let trueValue: Bool? = true
    try db.exec("INSERT INTO test (value) VALUES (\(trueValue))")

    let result1 = try db.query("SELECT value FROM test") { stmt, _ in
      try Optional<Bool>.column(of: stmt, at: 0)
    }
    #expect(result1.first == true)

    try db.exec("DELETE FROM test")
    let nilValue: Bool? = nil
    try db.exec("INSERT INTO test (value) VALUES (\(nilValue))")

    let result2 = try db.query("SELECT value FROM test") { stmt, _ in
      try Optional<Bool>.column(of: stmt, at: 0)
    }
    #expect(result2 == [nil])
  }

  @Test("Optional SQL literals")
  func testOptionalSQLLiterals() throws {
    let someValue: String? = "test"
    #expect(try someValue.asSQLLiteral() == "'test'")

    let nilValue: String? = nil
    #expect(try nilValue.asSQLLiteral() == "NULL")

    let someInt: Int? = 42
    #expect(try someInt.asSQLLiteral() == "42")

    let nilInt: Int? = nil
    #expect(try nilInt.asSQLLiteral() == "NULL")
  }

  @Test("Optional defaultSQLStorageType")
  func testOptionalDefaultSQLStorageType() {
    #expect(Optional<String>.defaultSQLStorageType == String.defaultSQLStorageType)
    #expect(Optional<Int>.defaultSQLStorageType == Int.defaultSQLStorageType)
    #expect(Optional<Double>.defaultSQLStorageType == Double.defaultSQLStorageType)
  }

  @Test("Non-optional column throws on NULL")
  func testNonOptionalThrowsOnNull() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value TEXT)")
    try db.exec("INSERT INTO test (value) VALUES (NULL)")

    #expect(throws: LoomError.self) {
      try db.query("SELECT value FROM test") { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    }
  }

  @Test("Multiple optional values mixed")
  func testMultipleOptionalValues() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    let values: [Int?] = [1, nil, 3, nil, 5]
    for val in values {
      try db.exec("INSERT INTO test (value) VALUES (\(val))")
    }

    let result = try db.query("SELECT value FROM test ORDER BY rowid") { stmt, _ in
      try Optional<Int>.column(of: stmt, at: 0)
    }

    #expect(result.count == 5)
    #expect(result == values)
  }
}
