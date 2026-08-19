import Foundation
import LoomCore
import Testing

@Suite("SQLStatement Tests")
@DatabaseActor
struct SQLStatementTests {
  @Test("SQLStatement from string literal")
  func testStringLiteral() {
    let stmt: SQLStatement = "SELECT * FROM users"

    #expect(stmt.sql == "SELECT * FROM users")
    #expect(stmt.binders.isEmpty)
  }

  @Test("SQLStatement with string interpolation")
  func testStringInterpolation() {
    let name = "Alice"
    let age = 25
    let stmt: SQLStatement = "SELECT * FROM users WHERE name = \(name) AND age = \(age)"

    #expect(stmt.sql.contains("?"))
    #expect(stmt.binders.count == 2)
  }

  @Test("SQLStatement.raw creates statement without binders")
  func testRawStatement() {
    let stmt = SQLStatement.raw("CREATE TABLE users (id INTEGER PRIMARY KEY)")

    #expect(stmt.sql == "CREATE TABLE users (id INTEGER PRIMARY KEY)")
    #expect(stmt.binders.isEmpty)
  }

  @Test("SQLStatement execution with database")
  func testStatementExecution() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    let name = "Alice"
    let age = 25
    let stmt: SQLStatement = "INSERT INTO users (name, age) VALUES (\(name), \(age))"

    try await db.exec(stmt)

    let result = try await db.query("SELECT name, age FROM users") { stmt, _ in
      let n = try String.column(of: stmt, at: 0)
      let a = try Int.column(of: stmt, at: 1)
      return (n, a)
    }

    #expect(result.first?.0 == "Alice")
    #expect(result.first?.1 == 25)
  }

  @Test("SQLStatement with optional values")
  func testStatementWithOptionals() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (name TEXT, email TEXT)")

    let name = "Bob"
    let email: String? = nil
    let stmt: SQLStatement = "INSERT INTO users (name, email) VALUES (\(name), \(email))"

    try await db.exec(stmt)

    let result = try await db.query("SELECT name, email FROM users") { stmt, _ in
      let n = try String.column(of: stmt, at: 0)
      let e = try Optional<String>.column(of: stmt, at: 1)
      return (n, e)
    }

    #expect(result.first?.0 == "Bob")
    #expect(result.first?.1 == nil)
  }

  @Test("SQLStatement with multiple data types")
  func testStatementWithMixedTypes() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (str TEXT, int INTEGER, double DOUBLE, bool BOOLEAN, data BLOB)")

    let str = "test"
    let int = 42
    let double = 3.14
    let bool = true
    let data = Data([0x01, 0x02])

    let stmt: SQLStatement =
      "INSERT INTO test (str, int, double, bool, data) VALUES (\(str), \(int), \(double), \(bool), \(data))"

    try await db.exec(stmt)

    let result = try await db.query("SELECT str, int, double, bool, data FROM test") { stmt, _ in
      let s = try String.column(of: stmt, at: 0)
      let i = try Int.column(of: stmt, at: 1)
      let d = try Double.column(of: stmt, at: 2)
      let b = try Bool.column(of: stmt, at: 3)
      let dt = try Data.column(of: stmt, at: 4)
      return (s, i, d, b, dt)
    }

    #expect(result.first?.0 == str)
    #expect(result.first?.1 == int)
    #expect(result.first?.2 == double)
    #expect(result.first?.3 == bool)
    #expect(result.first?.4 == data)
  }

  @Test("SQLStatement in query")
  func testStatementInQuery() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER)")
    try await db.exec("INSERT INTO users (name, age) VALUES ('Alice', 25)")
    try await db.exec("INSERT INTO users (name, age) VALUES ('Bob', 30)")

    let minAge = 26
    let stmt: SQLStatement = "SELECT name FROM users WHERE age >= \(minAge)"

    let result = try await db.query(stmt) { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.count == 1)
    #expect(result.first == "Bob")
  }

  @Test("SQLStatement with special characters in strings")
  func testStatementWithSpecialCharacters() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value TEXT)")

    let specialStr = "Test with 'quotes' and \"double\" and \\ backslash"
    let stmt: SQLStatement = "INSERT INTO test (value) VALUES (\(specialStr))"

    try await db.exec(stmt)

    let result = try await db.query("SELECT value FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == specialStr)
  }

  @Test("SQLStatement reuse")
  func testStatementReuse() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    let name = "Alice"
    let age = 25
    let stmt: SQLStatement = "INSERT INTO users (name, age) VALUES (\(name), \(age))"

    // Execute the same statement multiple times
    try await db.exec(stmt)
    try await db.exec(stmt)

    let result = try await db.query("SELECT COUNT(*) FROM users") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 2)
  }

  @Test("SQLStatement with UUID")
  func testStatementWithUUID() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (id BLOB)")

    let uuid = UUID()
    let stmt: SQLStatement = "INSERT INTO test (id) VALUES (\(uuid))"

    try await db.exec(stmt)

    let result = try await db.query("SELECT id FROM test") { stmt, _ in
      try UUID.column(of: stmt, at: 0)
    }

    #expect(result.first == uuid)
  }

  @Test("SQLStatement with Date")
  func testStatementWithDate() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (created DOUBLE)")

    let date = Date(timeIntervalSince1970: 1234567890.0)
    let stmt: SQLStatement = "INSERT INTO test (created) VALUES (\(date))"

    try await db.exec(stmt)

    let result = try await db.query("SELECT created FROM test") { stmt, _ in
      try Date.column(of: stmt, at: 0)
    }

    #expect(result.first == date)
  }

  // MARK: - Operator Tests

  @Test("SQLStatement += operator execution with database")
  func testPlusEqualsOperatorExecution() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER)")
    try await db.exec("INSERT INTO users (name, age) VALUES ('Alice', 25)")
    try await db.exec("INSERT INTO users (name, age) VALUES ('Bob', 30)")

    var stmt: SQLStatement = "INSERT INTO users (name, age)"
    stmt += "VALUES"

    let name = "Charlie"
    let age = 35
    stmt += "(\(name), \(age))"

    try await db.exec(stmt)

    let result = try await db.query("SELECT name, age FROM users WHERE name = 'Charlie'") { stmt, _ in
      let n = try String.column(of: stmt, at: 0)
      let a = try Int.column(of: stmt, at: 1)
      return (n, a)
    }

    #expect(result.first?.0 == "Charlie")
    #expect(result.first?.1 == 35)
  }

  @Test("SQLStatement + operator with multiple binders")
  func testPlusOperatorMultipleBinders() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER, active INTEGER)")
    try await db.exec("INSERT INTO users (name, age, active) VALUES ('Alice', 25, 1)")
    try await db.exec("INSERT INTO users (name, age, active) VALUES ('Bob', 30, 0)")
    try await db.exec("INSERT INTO users (name, age, active) VALUES ('Charlie', 35, 1)")

    let minAge = 26
    let active = true

    let stmt1: SQLStatement = "SELECT name FROM users WHERE age > \(minAge)"
    let stmt2: SQLStatement = "AND active = \(active)"
    let combined = stmt1 + stmt2

    #expect(combined.binders.count == 2)

    let result = try await db.query(combined) { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.count == 1)
    #expect(result.first == "Charlie")
  }

  // Pins in-place append semantics across many fragments: exact SQL text (one
  // space per join), binder count and order, and a full round trip through
  // binding and execution.
  @Test("SQLStatement += accumulates many fragments")
  func testPlusEqualsAccumulatesManyFragments() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE t (value INTEGER)")

    let count = 50
    var insert: SQLStatement = "INSERT INTO t (value)"
    insert += "VALUES"
    var expectedSQL = insert.sql
    for value in 1...count {
      let fragment: SQLStatement = value == 1 ? "(\(value))" : ", (\(value))"
      expectedSQL += " " + fragment.sql
      insert += fragment
    }

    #expect(insert.sql == expectedSQL)
    #expect(insert.binders.count == count)

    try await db.exec(insert)
    let values = try await db.query("SELECT value FROM t ORDER BY value") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(values == Array(1...count))
  }
}
