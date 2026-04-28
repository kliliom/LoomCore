import Foundation
import LoomCore
import Testing

@Suite("Function Avg Tests")
@DatabaseActor
struct FunctionAvgTests {
  @Test("Avg function")
  func testAvg() throws {
    let db = try Database.openInMemory()

    // Create a table with numeric data
    try db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    // Insert test data
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (100)")
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (200)")
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (300)")
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (150)")

    // Test expression
    let expr = ColumnExpression<Int>("amount").avg()

    // Query using AVG function
    let result = try db.query(
      "SELECT \(expr) FROM sales",
      stepper: { stmt, _ in
        try Double?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == 187.5)
  }

  @Test("Avg function with no rows")
  func testAvgNoRows() throws {
    let db = try Database.openInMemory()

    // Create a table with numeric data
    try db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    // Test expression
    let expr = ColumnExpression<Int>("amount").avg()

    // Query using AVG function
    let result = try db.query(
      "SELECT \(expr) FROM sales",
      stepper: { stmt, _ in
        try Double?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == nil)
  }
}
