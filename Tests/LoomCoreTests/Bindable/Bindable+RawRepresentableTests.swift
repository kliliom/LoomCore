import Foundation
import LoomCore
import Testing

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

  // Regression: a Codable raw-value enum used to hit "ambiguous witness" because
  // JSON storage was a default for every Codable Bindable. With JSON storage
  // opt-in via JSONBindable, this declaration compiles and stores the raw value.
  enum Role: String, Codable, Bindable {
    case admin
    case member
  }

  enum Level: Int, Codable, Bindable {
    case debug = 0
    case info = 1
  }

  @Test("String-based enum binding and extraction")
  func testStringEnumBinding() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (status TEXT)")

    let status = Status.active
    try await db.exec("INSERT INTO test (status) VALUES (\(status))")

    let result = try await db.query("SELECT status FROM test") { stmt, _ in
      try Status.column(of: stmt, at: 0)
    }

    #expect(result.first == .active)
  }

  @Test("Int-based enum binding and extraction")
  func testIntEnumBinding() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (priority INTEGER)")

    let priority = Priority.high
    try await db.exec("INSERT INTO test (priority) VALUES (\(priority))")

    let result = try await db.query("SELECT priority FROM test") { stmt, _ in
      try Priority.column(of: stmt, at: 0)
    }

    #expect(result.first == .high)
  }

  @Test("Multiple enum values")
  func testMultipleEnumValues() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (status TEXT)")

    let statuses: [Status] = [.active, .inactive, .pending]
    for status in statuses {
      try await db.exec("INSERT INTO test (status) VALUES (\(status))")
    }

    let result = try await db.query("SELECT status FROM test ORDER BY rowid") { stmt, _ in
      try Status.column(of: stmt, at: 0)
    }

    #expect(result.count == 3)
    #expect(result == statuses)
  }

  @Test("Enum as SQL literal")
  func testEnumAsSQLLiteral() async throws {
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

    try await db.exec("CREATE TABLE tasks (id INTEGER, status TEXT)")

    try await db.exec("INSERT INTO tasks (id, status) VALUES (1, \(Status.active))")
    try await db.exec("INSERT INTO tasks (id, status) VALUES (2, \(Status.inactive))")
    try await db.exec("INSERT INTO tasks (id, status) VALUES (3, \(Status.active))")

    let activeStatus = Status.active
    let result = try await db.query("SELECT id FROM tasks WHERE status = \(activeStatus) ORDER BY id") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.count == 2)
    #expect(result == [1, 3])
  }

  @Test("Optional enum binding")
  func testOptionalEnumBinding() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (status TEXT)")

    let status1: Status? = .active
    let status2: Status? = nil

    try await db.exec("INSERT INTO test (status) VALUES (\(status1))")
    try await db.exec("INSERT INTO test (status) VALUES (\(status2))")

    let result = try await db.query("SELECT status FROM test ORDER BY rowid") { stmt, _ in
      try Optional<Status>.column(of: stmt, at: 0)
    }

    #expect(result.count == 2)
    #expect(result[0] == .active)
    #expect(result[1] == nil)
  }

  @Test("Enum round-trip with all cases")
  func testEnumRoundTripAllCases() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (priority INTEGER)")

    let priorities: [Priority] = [.low, .medium, .high]
    for priority in priorities {
      try await db.exec("INSERT INTO test (priority) VALUES (\(priority))")
    }

    let result = try await db.query("SELECT priority FROM test ORDER BY priority") { stmt, _ in
      try Priority.column(of: stmt, at: 0)
    }

    #expect(result == [.low, .medium, .high])
  }

  @Test("Type mapping failed for invalid raw value")
  func testTypeMappingFailed() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (status TEXT)")

    // Insert an invalid raw value that doesn't correspond to any enum case
    try await db.exec(raw: "INSERT INTO test (status) VALUES ('invalid')")

    // Should throw typeMappingFailed when trying to read invalid value as enum
    await #expect(throws: LoomError.self) {
      try await db.query("SELECT status FROM test") { stmt, _ in
        try Status.column(of: stmt, at: 0)
      }
    }
  }

  @Test("Codable raw-value enums conform without ambiguity and store the raw value")
  func testCodableRawValueEnums() async throws {
    #expect(Role.defaultSQLStorageType == "TEXT")
    #expect(Level.defaultSQLStorageType == "INTEGER")

    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE test (role TEXT, level INTEGER)")
    try await db.exec("INSERT INTO test (role, level) VALUES (\(Role.admin), \(Level.info))")

    // Raw-value storage, not JSON: 'admin', not '"admin"'.
    let raw = try await db.query("SELECT role, level FROM test") { stmt, _ in
      (try String.column(of: stmt, at: 0), try Int.column(of: stmt, at: 1))
    }
    #expect(raw.first?.0 == "admin")
    #expect(raw.first?.1 == 1)

    let typed = try await db.query("SELECT role, level FROM test") { stmt, _ in
      (try Role.column(of: stmt, at: 0), try Level.column(of: stmt, at: 1))
    }
    #expect(typed.first?.0 == .admin)
    #expect(typed.first?.1 == .info)
  }
}
