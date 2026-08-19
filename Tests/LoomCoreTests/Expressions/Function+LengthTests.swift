import Foundation
import LoomCore
import Testing

@Suite("Function Length Tests")
@DatabaseActor
struct FunctionLengthTests {
  @Test("Length function")
  func testLength() async throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try await db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")

    // Insert test data
    try await db.exec(raw: "INSERT INTO users (name) VALUES ('John')")
    try await db.exec(raw: "INSERT INTO users (name) VALUES ('Jane')")
    try await db.exec(raw: "INSERT INTO users (name) VALUES ('Alexander')")

    // Test expression
    let expr = ColumnExpression<String>("name").length()

    // Query using LENGTH function
    let result = try await db.query(
      "SELECT \(expr) FROM users ORDER BY id",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 3)
    #expect(result[0] == 4)  // "John"
    #expect(result[1] == 4)  // "Jane"
    #expect(result[2] == 9)  // "Alexander"
  }

  @Test("Length function with empty string")
  func testLengthEmptyString() async throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try await db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")

    // Insert test data with empty string
    try await db.exec(raw: "INSERT INTO users (name) VALUES ('')")
    try await db.exec(raw: "INSERT INTO users (name) VALUES ('Bob')")

    // Test expression
    let expr = ColumnExpression<String>("name").length()

    // Query using LENGTH function
    let result = try await db.query(
      "SELECT \(expr) FROM users ORDER BY id",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 2)
    #expect(result[0] == 0)  // empty string
    #expect(result[1] == 3)  // "Bob"
  }

  @Test("Length function with no rows")
  func testLengthNoRows() async throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try await db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")

    // Test expression
    let expr = ColumnExpression<String>("name").length()

    // Query using LENGTH function
    let result = try await db.query(
      "SELECT \(expr) FROM users",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 0)
  }
}
