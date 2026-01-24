import Foundation
import Testing

@testable import LoomCore

@Suite("InExpression Tests")
@DatabaseActor
struct InExpressionTests {
  let db: Database

  init() throws {
    db = try Database.openInMemory()
    try db.exec("CREATE TABLE categories (id INTEGER PRIMARY KEY, name TEXT)")
    try db.exec("CREATE TABLE products (id INTEGER PRIMARY KEY, category_id INTEGER)")
    try prepareDatabase()
  }

  func prepareDatabase() throws {
    // Insert categories
    try db.exec(raw: "INSERT INTO categories (id, name) VALUES (2, 'Electronics')")
    try db.exec(raw: "INSERT INTO categories (id, name) VALUES (4, 'Books')")

    // Insert products
    try db.exec(raw: "INSERT INTO products (category_id) VALUES (1)")
    try db.exec(raw: "INSERT INTO products (category_id) VALUES (2)")
    try db.exec(raw: "INSERT INTO products (category_id) VALUES (3)")
    try db.exec(raw: "INSERT INTO products (category_id) VALUES (4)")
    try db.exec(raw: "INSERT INTO products (category_id) VALUES (5)")
  }

  @Test("IN expression from array")
  func testInExpressionFromArray() throws {
    // Test expression - check if category_id is in [2, 4]
    let expr = ColumnExpression<Int>("category_id").in(array: [2, 4])

    // Query using IN expression
    let result = try db.query(
      "SELECT category_id FROM products WHERE \(expr) ORDER BY category_id",
      stepper: { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }
    )

    try #require(result.count == 2)
    #expect(result[0] == 2)
    #expect(result[1] == 4)
  }

  @Test("NOT IN expression from array")
  func testNotInExpressionFromArray() throws {
    // Test expression - check if category_id is NOT in [1, 3, 5]
    let expr = ColumnExpression<Int>("category_id").notIn(array: [1, 3, 5])

    // Query using NOT IN expression
    let result = try db.query(
      "SELECT category_id FROM products WHERE \(expr) ORDER BY category_id",
      stepper: { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }
    )

    try #require(result.count == 2)
    #expect(result[0] == 2)
    #expect(result[1] == 4)
  }

  @Test("IN expression from variadic parameters")
  func testInExpressionFromVariadic() throws {
    // Test expression - check if category_id is in 2, 4
    let expr = ColumnExpression<Int>("category_id").in(values: 2, 4)

    // Query using IN expression
    let result = try db.query(
      "SELECT category_id FROM products WHERE \(expr) ORDER BY category_id",
      stepper: { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }
    )

    try #require(result.count == 2)
    #expect(result[0] == 2)
    #expect(result[1] == 4)
  }

  @Test("NOT IN expression from variadic parameters")
  func testNotInExpressionFromVariadic() throws {
    // Test expression - check if category_id is NOT in 1, 3, 5
    let expr = ColumnExpression<Int>("category_id").notIn(values: 1, 3, 5)

    // Query using NOT IN expression
    let result = try db.query(
      "SELECT category_id FROM products WHERE \(expr) ORDER BY category_id",
      stepper: { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }
    )

    try #require(result.count == 2)
    #expect(result[0] == 2)
    #expect(result[1] == 4)
  }
}
