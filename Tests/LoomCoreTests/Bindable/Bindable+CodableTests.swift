import Foundation
import LoomCore
import Testing

@Suite("Codable Bindable Tests")
@DatabaseActor
struct BindableCodableTests {
  struct Person: Codable, Bindable, Equatable {
    let name: String
    let age: Int
  }

  @Test("Codable struct binding and extraction")
  func testCodableStructBinding() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")

    let person = Person(name: "Alice", age: 25)
    try await db.exec("INSERT INTO test (data) VALUES (\(person))")

    let result = try await db.query("SELECT data FROM test") { stmt, _ in
      try Person.column(of: stmt, at: 0)
    }

    #expect(result.first == person)
  }

  @Test("Multiple Codable values")
  func testMultipleCodableValues() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")

    let people = [
      Person(name: "Alice", age: 25),
      Person(name: "Bob", age: 30),
      Person(name: "Charlie", age: 35),
    ]

    for person in people {
      try await db.exec("INSERT INTO test (data) VALUES (\(person))")
    }

    let result = try await db.query("SELECT data FROM test ORDER BY rowid") { stmt, _ in
      try Person.column(of: stmt, at: 0)
    }

    #expect(result.count == 3)
    #expect(result == people)
  }

  @Test("Codable with nested structure")
  func testCodableNestedStructure() async throws {
    struct Address: Codable, Equatable {
      let street: String
      let city: String
    }

    struct Employee: Codable, Bindable, Equatable {
      let name: String
      let address: Address
    }

    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")

    let employee = Employee(
      name: "Alice",
      address: Address(street: "123 Main St", city: "Springfield")
    )
    try await db.exec("INSERT INTO test (data) VALUES (\(employee))")

    let result = try await db.query("SELECT data FROM test") { stmt, _ in
      try Employee.column(of: stmt, at: 0)
    }

    #expect(result.first == employee)
  }

  @Test("Codable as SQL literal")
  func testCodableAsSQLLiteral() async throws {
    let person = Person(name: "Alice", age: 25)
    let literal = try person.asSQLLiteral()

    #expect(literal.hasPrefix("'{"))
    #expect(literal.hasSuffix("}'"))
    #expect(literal.contains(#""name":"Alice""#))
    #expect(literal.contains(#""age":25"#))
  }

  @Test("Codable defaultSQLStorageType")
  func testCodableDefaultSQLStorageType() {
    #expect(Person.defaultSQLStorageType == "TEXT")
  }

  @Test("Codable binds as TEXT storage")
  func testCodableBindsAsText() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec("INSERT INTO test (data) VALUES (\(Person(name: "Alice", age: 25)))")

    let storage = try await db.query("SELECT typeof(data) FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(storage.first == "text")
  }

  @Test("Codable works with SQLite JSON functions")
  func testCodableWithJSONFunctions() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec("INSERT INTO test (data) VALUES (\(Person(name: "Alice", age: 25)))")

    let result = try await db.query("SELECT json_extract(data, '$.name'), data ->> '$.age' FROM test") { stmt, _ in
      (try String.column(of: stmt, at: 0), try Int.column(of: stmt, at: 1))
    }

    #expect(result.first?.0 == "Alice")
    #expect(result.first?.1 == 25)
  }

  @Test("Codable reads legacy BLOB storage")
  func testCodableReadsLegacyBlobStorage() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data BLOB)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES (CAST('{"name":"Alice","age":25}' AS BLOB))"#)

    let result = try await db.query("SELECT typeof(data), data FROM test") { stmt, _ in
      (try String.column(of: stmt, at: 0), try Person.column(of: stmt, at: 1))
    }

    #expect(result.first?.0 == "blob")
    #expect(result.first?.1 == Person(name: "Alice", age: 25))
  }

  @Test("Codable with optional fields")
  func testCodableWithOptionalFields() async throws {
    struct Profile: Codable, Bindable, Equatable {
      let name: String
      let email: String?
    }

    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")

    let profile1 = Profile(name: "Alice", email: "alice@example.com")
    let profile2 = Profile(name: "Bob", email: nil)

    try await db.exec("INSERT INTO test (data) VALUES (\(profile1))")
    try await db.exec("INSERT INTO test (data) VALUES (\(profile2))")

    let result = try await db.query("SELECT data FROM test ORDER BY rowid") { stmt, _ in
      try Profile.column(of: stmt, at: 0)
    }

    #expect(result.count == 2)
    #expect(result[0] == profile1)
    #expect(result[1] == profile2)
  }

  @Test("Codable with arrays")
  func testCodableWithArrays() async throws {
    struct Team: Codable, Bindable, Equatable {
      let name: String
      let members: [String]
    }

    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")

    let team = Team(name: "Dev Team", members: ["Alice", "Bob", "Charlie"])
    try await db.exec("INSERT INTO test (data) VALUES (\(team))")

    let result = try await db.query("SELECT data FROM test") { stmt, _ in
      try Team.column(of: stmt, at: 0)
    }

    #expect(result.first == team)
  }

  @Test("Codable throws unexpectedNullValue for NULL")
  func testCodableUnexpectedNullValue() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: "INSERT INTO test (data) VALUES (NULL)")

    await #expect(throws: LoomError.core(.nullValue, message: "Column at index 0 is NULL, cannot return Person.")) {
      try await db.query("SELECT data FROM test") { stmt, _ in
        try Person.column(of: stmt, at: 0)
      }
    }
  }

  @Test("Codable decodes from TEXT storage")
  func testCodableFromText() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"name":"Alice","age":25}')"#)

    let result = try await db.query("SELECT data FROM test") { stmt, _ in
      try Person.column(of: stmt, at: 0)
    }

    #expect(result.first == Person(name: "Alice", age: 25))
  }

  @Test("Codable throws typeMappingFailed for INTEGER and REAL storage")
  func testCodableRejectsNumericStorage() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data)")
    try await db.exec(raw: "INSERT INTO test (data) VALUES (42)")
    try await db.exec(raw: "INSERT INTO test (data) VALUES (1.5)")

    await #expect(
      throws: LoomError.core(
        .typeMappingFailed,
        message: "Column at index 0 has storage class INTEGER, cannot return Person."
      )
    ) {
      try await db.query("SELECT data FROM test WHERE typeof(data) = 'integer'") { stmt, _ in
        try Person.column(of: stmt, at: 0)
      }
    }
    await #expect(
      throws: LoomError.core(
        .typeMappingFailed,
        message: "Column at index 0 has storage class REAL, cannot return Person."
      )
    ) {
      try await db.query("SELECT data FROM test WHERE typeof(data) = 'real'") { stmt, _ in
        try Person.column(of: stmt, at: 0)
      }
    }
  }

  @Test("Codable throws typeMappingFailed for an empty payload")
  func testCodableEmptyPayload() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data)")
    try await db.exec(raw: "INSERT INTO test (data) VALUES ('')")
    try await db.exec(raw: "INSERT INTO test (data) VALUES (X'')")

    for storage in ["text", "blob"] {
      await #expect(
        throws: LoomError.core(
          .typeMappingFailed,
          message: "Column at index 0 is empty, which is not valid JSON, cannot return Person."
        )
      ) {
        try await db.query("SELECT data FROM test WHERE typeof(data) = \(storage)") { stmt, _ in
          try Person.column(of: stmt, at: 0)
        }
      }
    }
  }

  @Test("Codable propagates DecodingError for malformed JSON")
  func testCodableMalformedJSON() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: "INSERT INTO test (data) VALUES ('not json')")

    await #expect(throws: DecodingError.self) {
      try await db.query("SELECT data FROM test") { stmt, _ in
        try Person.column(of: stmt, at: 0)
      }
    }
  }

  @Test("Codable bind throws with connection error message on out-of-range index")
  func testCodableBindOutOfRangeIndex() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE test (data TEXT)")

    let error = await #expect(throws: LoomError.self) {
      try await db.exec(
        raw: "INSERT INTO test (data) VALUES (?)",
        binder: { stmt in
          try Person(name: "Alice", age: 25).bind(to: stmt, at: 99)
        }
      )
    }
    let message = try #require(error?.message)
    #expect(!message.isEmpty)
  }
}
