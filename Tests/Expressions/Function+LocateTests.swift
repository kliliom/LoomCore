import Foundation
import Testing

@testable import LoomCore

@Suite("Function Locate Tests")
@DatabaseActor
struct FunctionLocateTests {
  @Test("Locate function")
  func testLocate() throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT)")

    // Insert test data
    try db.exec(raw: "INSERT INTO users (email) VALUES ('john@example.com')")
    try db.exec(raw: "INSERT INTO users (email) VALUES ('jane@test.org')")
    try db.exec(raw: "INSERT INTO users (email) VALUES ('bob@sample.net')")

    // Test expression - find position of '@'
    let expr = ColumnExpression<String>("email").locate("@")

    // Query using INSTR function
    let result = try db.query(
      "SELECT \(expr) FROM users ORDER BY id",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 3)
    #expect(result[0] == 5)  // "john@example.com" - @ is at position 5
    #expect(result[1] == 5)  // "jane@test.org" - @ is at position 5
    #expect(result[2] == 4)  // "bob@sample.net" - @ is at position 4
  }

  @Test("Locate function not found")
  func testLocateNotFound() throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT)")

    // Insert test data
    try db.exec(raw: "INSERT INTO users (email) VALUES ('john.example.com')")
    try db.exec(raw: "INSERT INTO users (email) VALUES ('jane.test.org')")

    // Test expression - find position of '@' (not present)
    let expr = ColumnExpression<String>("email").locate("@")

    // Query using INSTR function
    let result = try db.query(
      "SELECT \(expr) FROM users ORDER BY id",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 2)
    #expect(result[0] == 0)  // 0 means not found
    #expect(result[1] == 0)  // 0 means not found
  }

  @Test("Locate function with no rows")
  func testLocateNoRows() throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT)")

    // Test expression
    let expr = ColumnExpression<String>("email").locate("@")

    // Query using INSTR function
    let result = try db.query(
      "SELECT \(expr) FROM users",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 0)
  }
}
