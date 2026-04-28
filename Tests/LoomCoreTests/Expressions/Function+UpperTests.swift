import Foundation
import LoomCore
import Testing

@Suite("Function Upper Tests")
@DatabaseActor
struct FunctionUpperTests {
  @Test("Upper function")
  func testUpper() throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")

    // Insert test data
    try db.exec(raw: "INSERT INTO users (name) VALUES ('john')")
    try db.exec(raw: "INSERT INTO users (name) VALUES ('Jane')")
    try db.exec(raw: "INSERT INTO users (name) VALUES ('bob')")

    // Test expression
    let expr = ColumnExpression<String>("name").upper()

    // Query using UPPER function
    let result = try db.query(
      "SELECT \(expr) FROM users ORDER BY id",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 3)
    #expect(result[0] == "JOHN")
    #expect(result[1] == "JANE")
    #expect(result[2] == "BOB")
  }

  @Test("Upper function with no rows")
  func testUpperNoRows() throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")

    // Test expression
    let expr = ColumnExpression<String>("name").upper()

    // Query using UPPER function
    let result = try db.query(
      "SELECT \(expr) FROM users",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 0)
  }
}
