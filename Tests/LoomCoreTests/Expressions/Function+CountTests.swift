import Foundation
import LoomCore
import Testing

@Suite("Function Count Tests")
@DatabaseActor
struct FunctionCountTests {
  @Test("Count function")
  func testCount() throws {
    let db = try Database.openInMemory()

    // Create a table with numeric data
    try db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    // Insert test data
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (100)")
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (200)")
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (300)")
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (150)")

    // Test expression
    let expr = ColumnExpression<Int>("amount").count()

    // Query using COUNT function
    let result = try db.query(
      "SELECT \(expr) FROM sales",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == 4)
  }

  @Test("Count function with no rows")
  func testCountNoRows() throws {
    let db = try Database.openInMemory()

    // Create a table with numeric data
    try db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    // Test expression
    let expr = ColumnExpression<Int>("amount").count()

    // Query using COUNT function
    let result = try db.query(
      "SELECT \(expr) FROM sales",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == 0)
  }

  @Test("Count distinct function")
  func testCountDistinct() throws {
    let db = try Database.openInMemory()

    // Create a table with numeric data
    try db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    // Insert test data with duplicates
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (100)")
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (200)")
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (100)")
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (200)")
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (300)")

    // Test expression with distinct
    let expr = ColumnExpression<Int>("amount").count(distinct: true)

    // Query using COUNT(DISTINCT) function
    let result = try db.query(
      "SELECT \(expr) FROM sales",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == 3)
  }

  @Test("Count distinct vs regular count")
  func testCountDistinctVsRegular() throws {
    let db = try Database.openInMemory()

    // Create a table with numeric data
    try db.exec("CREATE TABLE sales (id INTEGER PRIMARY KEY, amount INTEGER)")

    // Insert test data with duplicates
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (100)")
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (200)")
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (100)")
    try db.exec(raw: "INSERT INTO sales (amount) VALUES (200)")

    // Test regular count
    let regularExpr = ColumnExpression<Int>("amount").count()
    let regularResult = try db.query(
      "SELECT \(regularExpr) FROM sales",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    // Test distinct count
    let distinctExpr = ColumnExpression<Int>("amount").count(distinct: true)
    let distinctResult = try db.query(
      "SELECT \(distinctExpr) FROM sales",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(regularResult[0] == 4)
    #expect(distinctResult[0] == 2)
  }
}
