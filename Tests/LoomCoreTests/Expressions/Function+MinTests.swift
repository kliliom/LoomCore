import Foundation
import LoomCore
import Testing

@Suite("Function Min Tests")
@DatabaseActor
struct FunctionMinTests {
  @Test("Min function")
  func testMin() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (100)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (200)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (300)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (150)")

    let expr = ColumnExpression<Int>("amount").min()

    let result = try await db.query(
      "SELECT \(expr) FROM sales",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == 100)
  }

  @Test("Min function with no rows")
  func testMinNoRows() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    let expr = ColumnExpression<Int>("amount").min()

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
