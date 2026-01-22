import Foundation
import Testing

@testable import LoomCore

@Suite("RawRepresentable Bindable Tests")
@DatabaseActor
struct BindableRawRepresentableTests {
  enum Status: String, Bindable {
    case active
    case inactive
    case pending
  }

  enum Priority: Int, Bindable {
    case low = 1
    case medium = 2
    case high = 3
  }

  @Test("String-based enum binding and extraction")
  func testStringEnumBinding() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (status TEXT)")

    let status = Status.active
    try db.exec("INSERT INTO test (status) VALUES (\(status))")

    let result = try db.query("SELECT status FROM test") { stmt, _ in
      try Status.column(of: stmt, at: 0)
    }

    #expect(result.first == .active)
  }

  @Test("Int-based enum binding and extraction")
  func testIntEnumBinding() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (priority INTEGER)")

    let priority = Priority.high
    try db.exec("INSERT INTO test (priority) VALUES (\(priority))")

    let result = try db.query("SELECT priority FROM test") { stmt, _ in
      try Priority.column(of: stmt, at: 0)
    }

    #expect(result.first == .high)
  }

  @Test("Multiple enum values")
  func testMultipleEnumValues() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (status TEXT)")

    let statuses: [Status] = [.active, .inactive, .pending]
    for status in statuses {
      try db.exec("INSERT INTO test (status) VALUES (\(status))")
    }

    let result = try db.query("SELECT status FROM test ORDER BY rowid") { stmt, _ in
      try Status.column(of: stmt, at: 0)
    }

    #expect(result.count == 3)
    #expect(result == statuses)
  }

  @Test("Enum as SQL literal")
  func testEnumAsSQLLiteral() throws {
    let status = Status.active
    #expect(try status.asSQLLiteral() == "'active'")

    let priority = Priority.high
    #expect(try priority.asSQLLiteral() == "3")
  }

  @Test("Enum defaultSQLStorageType")
  func testEnumDefaultSQLStorageType() {
    #expect(Status.defaultSQLStorageType == "TEXT")
    #expect(Priority.defaultSQLStorageType == "INTEGER")
  }

  @Test("Enum with query filtering")
  func testEnumWithQueryFiltering() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE tasks (id INTEGER, status TEXT)")

    try db.exec("INSERT INTO tasks (id, status) VALUES (1, \(Status.active))")
    try db.exec("INSERT INTO tasks (id, status) VALUES (2, \(Status.inactive))")
    try db.exec("INSERT INTO tasks (id, status) VALUES (3, \(Status.active))")

    let activeStatus = Status.active
    let result = try db.query("SELECT id FROM tasks WHERE status = \(activeStatus) ORDER BY id") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.count == 2)
    #expect(result == [1, 3])
  }

  @Test("Optional enum binding")
  func testOptionalEnumBinding() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (status TEXT)")

    let status1: Status? = .active
    let status2: Status? = nil

    try db.exec("INSERT INTO test (status) VALUES (\(status1))")
    try db.exec("INSERT INTO test (status) VALUES (\(status2))")

    let result = try db.query("SELECT status FROM test ORDER BY rowid") { stmt, _ in
      try Optional<Status>.column(of: stmt, at: 0)
    }

    #expect(result.count == 2)
    #expect(result[0] == .active)
    #expect(result[1] == nil)
  }

  @Test("Enum round-trip with all cases")
  func testEnumRoundTripAllCases() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (priority INTEGER)")

    let priorities: [Priority] = [.low, .medium, .high]
    for priority in priorities {
      try db.exec("INSERT INTO test (priority) VALUES (\(priority))")
    }

    let result = try db.query("SELECT priority FROM test ORDER BY priority") { stmt, _ in
      try Priority.column(of: stmt, at: 0)
    }

    #expect(result == [.low, .medium, .high])
  }

  @Test("Type mapping failed for invalid raw value")
  func testTypeMappingFailed() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (status TEXT)")

    // Insert an invalid raw value that doesn't correspond to any enum case
    try db.exec(raw: "INSERT INTO test (status) VALUES ('invalid')")

    // Should throw typeMappingFailed when trying to read invalid value as enum
    #expect(throws: LoomError.self) {
      try db.query("SELECT status FROM test") { stmt, _ in
        try Status.column(of: stmt, at: 0)
      }
    }
  }
}
