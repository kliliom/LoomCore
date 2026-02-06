import Foundation
import LoomCore
import Testing

@Suite("Function Lower Tests")
@DatabaseActor
struct FunctionLowerTests {
  @Test("Lower function")
  func testLower() throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")

    // Insert test data
    try db.exec(raw: "INSERT INTO users (name) VALUES ('JOHN')")
    try db.exec(raw: "INSERT INTO users (name) VALUES ('Jane')")
    try db.exec(raw: "INSERT INTO users (name) VALUES ('BOB')")

    // Test expression
    let expr = ColumnExpression<String>("name").lower()

    // Query using LOWER function
    let result = try db.query(
      "SELECT \(expr) FROM users ORDER BY id",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 3)
    #expect(result[0] == "john")
    #expect(result[1] == "jane")
    #expect(result[2] == "bob")
  }

  @Test("Lower function with no rows")
  func testLowerNoRows() throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")

    // Test expression
    let expr = ColumnExpression<String>("name").lower()

    // Query using LOWER function
    let result = try db.query(
      "SELECT \(expr) FROM users",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 0)
  }
}
