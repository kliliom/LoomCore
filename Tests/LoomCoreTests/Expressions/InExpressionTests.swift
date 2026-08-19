import Foundation
import LoomCore
import Testing

@Suite("InExpression Tests")
@DatabaseActor
struct InExpressionTests {
  let db: Database

  init() async throws {
    db = try Database.openInMemory()
    try await db.exec("CREATE TABLE categories (id INTEGER PRIMARY KEY, name TEXT)")
    try await db.exec("CREATE TABLE products (id INTEGER PRIMARY KEY, category_id INTEGER)")
    try await prepareDatabase()
  }

  func prepareDatabase() async throws {
    // Insert categories
    try await db.exec(raw: "INSERT INTO categories (id, name) VALUES (2, 'Electronics')")
    try await db.exec(raw: "INSERT INTO categories (id, name) VALUES (4, 'Books')")

    // Insert products
    try await db.exec(raw: "INSERT INTO products (category_id) VALUES (1)")
    try await db.exec(raw: "INSERT INTO products (category_id) VALUES (2)")
    try await db.exec(raw: "INSERT INTO products (category_id) VALUES (3)")
    try await db.exec(raw: "INSERT INTO products (category_id) VALUES (4)")
    try await db.exec(raw: "INSERT INTO products (category_id) VALUES (5)")
  }

  @Test("IN expression from array")
  func testInExpressionFromArray() async throws {
    // Test expression - check if category_id is in [2, 4]
    let expr = ColumnExpression<Int>("category_id").in(array: [2, 4])

    // Query using IN expression
    let result = try await db.query(
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
  func testNotInExpressionFromArray() async throws {
    // Test expression - check if category_id is NOT in [1, 3, 5]
    let expr = ColumnExpression<Int>("category_id").notIn(array: [1, 3, 5])

    // Query using NOT IN expression
    let result = try await db.query(
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
  func testInExpressionFromVariadic() async throws {
    // Test expression - check if category_id is in 2, 4
    let expr = ColumnExpression<Int>("category_id").in(values: 2, 4)

    // Query using IN expression
    let result = try await db.query(
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
  func testNotInExpressionFromVariadic() async throws {
    // Test expression - check if category_id is NOT in 1, 3, 5
    let expr = ColumnExpression<Int>("category_id").notIn(values: 1, 3, 5)

    // Query using NOT IN expression
    let result = try await db.query(
      "SELECT category_id FROM products WHERE \(expr) ORDER BY category_id",
      stepper: { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }
    )

    try #require(result.count == 2)
    #expect(result[0] == 2)
    #expect(result[1] == 4)
  }

  @Test("IN expression with empty array matches no rows")
  func testInExpressionFromEmptyArray() async throws {
    let expr = ColumnExpression<Int>("category_id").in(array: [Int]())

    var builder = SQLBuilder()
    expr.append(to: &builder)
    #expect(builder.makeStatement().sql == "( \"category_id\" IN (NULL) AND 0 )")

    let result = try await db.query(
      "SELECT category_id FROM products WHERE \(expr)",
      stepper: { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }
    )
    #expect(result.isEmpty)
  }

  @Test("NOT IN expression with empty array matches all rows")
  func testNotInExpressionFromEmptyArray() async throws {
    let expr = ColumnExpression<Int>("category_id").notIn(array: [Int]())

    var builder = SQLBuilder()
    expr.append(to: &builder)
    #expect(builder.makeStatement().sql == "( \"category_id\" NOT IN (NULL) OR 1 )")

    let result = try await db.query(
      "SELECT category_id FROM products ORDER BY category_id",
      stepper: { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }
    )
    #expect(result.count == 5)
  }

  // IN predicates are typed Bool (not Bool?) so they compose with the logical
  // operators like any comparison does.
  @Test("IN predicate composes with AND")
  func testInPredicateComposesWithAnd() async throws {
    let categoryID = ColumnExpression<Int>("category_id")
    let expr = categoryID.in(array: [2, 3, 4]) && categoryID > 2

    let result = try await db.query(
      "SELECT category_id FROM products WHERE \(expr) ORDER BY category_id",
      stepper: { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }
    )
    #expect(result == [3, 4])
  }

  @Test("IN predicate negates with NOT")
  func testInPredicateNegatesWithNot() async throws {
    let categoryID = ColumnExpression<Int>("category_id")
    let expr = !categoryID.in(array: [2, 4])

    let result = try await db.query(
      "SELECT category_id FROM products WHERE \(expr) ORDER BY category_id",
      stepper: { stmt, _ in
        try Int.column(of: stmt, at: 0)
      }
    )
    #expect(result == [1, 3, 5])
  }
}
