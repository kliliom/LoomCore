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

    try db.exec("CREATE TABLE test (data BLOB)")

    let person = Person(name: "Alice", age: 25)
    try db.exec("INSERT INTO test (data) VALUES (\(person))")

    let result = try db.query("SELECT data FROM test") { stmt, _ in
      try Person.column(of: stmt, at: 0)
    }

    #expect(result.first == person)
  }

  @Test("Multiple Codable values")
  func testMultipleCodableValues() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (data BLOB)")

    let people = [
      Person(name: "Alice", age: 25),
      Person(name: "Bob", age: 30),
      Person(name: "Charlie", age: 35),
    ]

    for person in people {
      try db.exec("INSERT INTO test (data) VALUES (\(person))")
    }

    let result = try db.query("SELECT data FROM test ORDER BY rowid") { stmt, _ in
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

    try db.exec("CREATE TABLE test (data BLOB)")

    let employee = Employee(
      name: "Alice",
      address: Address(street: "123 Main St", city: "Springfield")
    )
    try db.exec("INSERT INTO test (data) VALUES (\(employee))")

    let result = try db.query("SELECT data FROM test") { stmt, _ in
      try Employee.column(of: stmt, at: 0)
    }

    #expect(result.first == employee)
  }

  @Test("Codable as SQL literal")
  func testCodableAsSQLLiteral() throws {
    let person = Person(name: "Alice", age: 25)
    let literal = try person.asSQLLiteral()

    #expect(literal.hasPrefix("X'"))
    #expect(literal.hasSuffix("'"))
  }

  @Test("Codable defaultSQLStorageType")
  func testCodableDefaultSQLStorageType() {
    #expect(Person.defaultSQLStorageType == "BLOB")
  }

  @Test("Codable with optional fields")
  func testCodableWithOptionalFields() async throws {
    struct Profile: Codable, Bindable, Equatable {
      let name: String
      let email: String?
    }

    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (data BLOB)")

    let profile1 = Profile(name: "Alice", email: "alice@example.com")
    let profile2 = Profile(name: "Bob", email: nil)

    try db.exec("INSERT INTO test (data) VALUES (\(profile1))")
    try db.exec("INSERT INTO test (data) VALUES (\(profile2))")

    let result = try db.query("SELECT data FROM test ORDER BY rowid") { stmt, _ in
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

    try db.exec("CREATE TABLE test (data BLOB)")

    let team = Team(name: "Dev Team", members: ["Alice", "Bob", "Charlie"])
    try db.exec("INSERT INTO test (data) VALUES (\(team))")

    let result = try db.query("SELECT data FROM test") { stmt, _ in
      try Team.column(of: stmt, at: 0)
    }

    #expect(result.first == team)
  }

  @Test("Codable throws unexpectedNullValue for NULL")
  func testCodableUnexpectedNullValue() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (data BLOB)")
    try db.exec(raw: "INSERT INTO test (data) VALUES (NULL)")

    #expect(throws: LoomError.core(.nullValue, message: "Column at index 0 is NULL, cannot decode to Person.")) {
      try db.query("SELECT data FROM test") { stmt, _ in
        try Person.column(of: stmt, at: 0)
      }
    }
  }
}
