import Foundation
import LoomCore
import Testing

@Suite("Function Avg Tests")
@DatabaseActor
struct FunctionAvgTests {
  @Test("Avg function")
  func testAvg() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (100)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (200)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (300)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (150)")

    let expr = ColumnExpression<Int>("amount").avg()

    let result = try await db.query(
      "SELECT \(expr) FROM sales",
      stepper: { stmt, _ in
        try Double?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == 187.5)
  }

  @Test("Avg function with no rows")
  func testAvgNoRows() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    let expr = ColumnExpression<Int>("amount").avg()

    let result = try await db.query(
      "SELECT \(expr) FROM sales",
      stepper: { stmt, _ in
        try Double?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == nil)
  }
}
