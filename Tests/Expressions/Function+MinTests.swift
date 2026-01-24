import Foundation
import Testing

@testable import LoomCore

@Suite("Function Min Tests")
@DatabaseActor
struct FunctionMinTests {
  @Test("Min function")
  func testMin() throws {
    let db = try Database.openInMemory()

    // Create a table with numeric data
    try db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    // Insert test data
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (100)")
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (200)")
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (300)")
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (150)")

    // Test expression
    let expr = ColumnExpression<Int>("amount").min()

    // Query using MIN function
    let result = try db.query(
      "SELECT \(expr) FROM sales",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == 100)
  }

  @Test("Min function with no rows")
  func testMinNoRows() throws {
    let db = try Database.openInMemory()

    // Create a table with numeric data
    try db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    // Test expression
    let expr = ColumnExpression<Int>("amount").min()

    // Query using MIN function
    let result = try db.query(
      "SELECT \(expr) FROM sales",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == nil)
  }
}
