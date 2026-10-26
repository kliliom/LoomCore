import Foundation
import LoomCore
import Testing

@Suite("Function Count Tests")
@DatabaseActor
struct FunctionCountTests {
  @Test("Count function")
  func testCount() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (100)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (200)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (300)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (150)")

    let expr = ColumnExpression<Int>("amount").count()

    let result = try await db.query(
      "SELECT \(expr) FROM sales",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == 4)
  }

  @Test("Count function with no rows")
  func testCountNoRows() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    let expr = ColumnExpression<Int>("amount").count()

    let result = try await db.query(
      "SELECT \(expr) FROM sales",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == 0)
  }

  @Test("Count distinct function")
  func testCountDistinct() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (100)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (200)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (100)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (200)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (300)")

    let expr = ColumnExpression<Int>("amount").count(distinct: true)

    let result = try await db.query(
      "SELECT \(expr) FROM sales",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == 3)
  }

  @Test("Count distinct vs regular count")
  func testCountDistinctVsRegular() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (100)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (200)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (100)")
    try await db.exec(raw: "INSERT INTO sales (amount) VALUES (200)")

    let regularExpr = ColumnExpression<Int>("amount").count()
    let regularResult = try await db.query(
      "SELECT \(regularExpr) FROM sales",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    let distinctExpr = ColumnExpression<Int>("amount").count(distinct: true)
    let distinctResult = try await db.query(
      "SELECT \(distinctExpr) FROM sales",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(regularResult[0] == 4)
    #expect(distinctResult[0] == 2)
  }
}
