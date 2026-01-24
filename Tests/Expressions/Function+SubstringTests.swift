import Foundation
import Testing

@testable import LoomCore

@Suite("Function Substring Tests")
@DatabaseActor
struct FunctionSubstringTests {
  @Test("Substring function with length")
  func testSubstringWithLength() throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT)")

    // Insert test data
    try db.exec(raw: "INSERT INTO users (email) VALUES ('john@example.com')")
    try db.exec(raw: "INSERT INTO users (email) VALUES ('jane@example.com')")

    // Test expression - extract first 4 characters
    let expr = ColumnExpression<String>("email").substring(start: 1, length: 4)

    // Query using SUBSTR function
    let result = try db.query(
      "SELECT \(expr) FROM users ORDER BY id",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 2)
    #expect(result[0] == "john")
    #expect(result[1] == "jane")
  }

  @Test("Substring function without length")
  func testSubstringWithoutLength() throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT)")

    // Insert test data
    try db.exec(raw: "INSERT INTO users (email) VALUES ('john@example.com')")
    try db.exec(raw: "INSERT INTO users (email) VALUES ('jane@example.com')")

    // Test expression - extract from position 6 to end
    let expr = ColumnExpression<String>("email").substring(start: 6)

    // Query using SUBSTR function
    let result = try db.query(
      "SELECT \(expr) FROM users ORDER BY id",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 2)
    #expect(result[0] == "example.com")
    #expect(result[1] == "example.com")
  }

  @Test("Substring function with no rows")
  func testSubstringNoRows() throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT)")

    // Test expression
    let expr = ColumnExpression<String>("email").substring(start: 1, length: 4)

    // Query using SUBSTR function
    let result = try db.query(
      "SELECT \(expr) FROM users",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 0)
  }
}
