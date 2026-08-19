import Foundation
import LoomCore
import Testing

@Suite("Function Sum Tests")
@DatabaseActor
struct FunctionSumTests {
  @Test("Sum function")
  func testSum() async throws {
    let db = try Database.openInMemory()

    // Create a table with numeric data
    try await db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    // Insert test data
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (100)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (200)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (300)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (150)")

    // Test expression
    let expr = ColumnExpression<Int>("amount").sum()

    // Query using SUM function
    let result = try await db.query(
      "SELECT \(expr) FROM sales",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == 750)
  }

  @Test("Sum function with no rows")
  func testSumNoRows() async throws {
    let db = try Database.openInMemory()

    // Create a table with numeric data
    try await db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    // Test expression
    let expr = ColumnExpression<Int>("amount").sum()

    // Query using SUM function
    let result = try await db.query(
      "SELECT \(expr) FROM sales",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == nil)
  }
}
