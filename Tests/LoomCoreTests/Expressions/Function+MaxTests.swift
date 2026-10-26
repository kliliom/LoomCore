import Foundation
import LoomCore
import Testing

@Suite("Function Max Tests")
@DatabaseActor
struct FunctionMaxTests {
  @Test("Max function")
  func testMax() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (100)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (200)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (300)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (150)")

    let expr = ColumnExpression<Int>("amount").max()

    let result = try await db.query(
      "SELECT \(expr) FROM sales",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == 300)
  }

  @Test("Max function with no rows")
  func testMaxNoRows() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    let expr = ColumnExpression<Int>("amount").max()

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
