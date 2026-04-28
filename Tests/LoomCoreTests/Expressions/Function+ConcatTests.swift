import Foundation
import LoomCore
import Testing

@Suite("Function Concat Tests")
@DatabaseActor
struct FunctionConcatTests {
  @Test("Concat function")
  func testConcat() throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, first_name TEXT, last_name TEXT)")

    // Insert test data
    try db.exec(raw: "INSERT INTO users (first_name, last_name) VALUES ('John', 'Doe')")
    try db.exec(raw: "INSERT INTO users (first_name, last_name) VALUES ('Jane', 'Smith')")

    // Test expression
    let expr = concat(
      ColumnExpression<String>("first_name"),
      " ",
      ColumnExpression<String>("last_name")
    )

    // Query using concatenation
    let result = try db.query(
      "SELECT \(expr) FROM users ORDER BY id",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 2)
    #expect(result[0] == "John Doe")
    #expect(result[1] == "Jane Smith")
  }

  @Test("Concat function with no rows")
  func testConcatNoRows() throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, first_name TEXT, last_name TEXT)")

    // Test expression
    let expr = concat(
      ColumnExpression<String>("first_name"),
      " ",
      ColumnExpression<String>("last_name")
    )

    // Query using concatenation
    let result = try db.query(
      "SELECT \(expr) FROM users",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 0)
  }
}
