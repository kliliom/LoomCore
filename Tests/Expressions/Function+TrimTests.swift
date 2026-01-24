import Foundation
import Testing

@testable import LoomCore

@Suite("Function Trim Tests")
@DatabaseActor
struct FunctionTrimTests {
  @Test("Trim function")
  func testTrim() throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")

    // Insert test data with whitespace
    try db.exec(raw: "INSERT INTO users (name) VALUES ('  John  ')")
    try db.exec(raw: "INSERT INTO users (name) VALUES (' Jane ')")
    try db.exec(raw: "INSERT INTO users (name) VALUES ('Bob')")

    // Test expression
    let expr = ColumnExpression<String>("name").trim()

    // Query using TRIM function
    let result = try db.query(
      "SELECT \(expr) FROM users ORDER BY id",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 3)
    #expect(result[0] == "John")
    #expect(result[1] == "Jane")
    #expect(result[2] == "Bob")
  }

  @Test("Trim function with no rows")
  func testTrimNoRows() throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")

    // Test expression
    let expr = ColumnExpression<String>("name").trim()

    // Query using TRIM function
    let result = try db.query(
      "SELECT \(expr) FROM users",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 0)
  }
}
