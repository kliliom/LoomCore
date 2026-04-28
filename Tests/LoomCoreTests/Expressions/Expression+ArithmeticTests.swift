import Foundation
import LoomCore
import Testing

@Suite("Expression Arithmetic Tests")
@DatabaseActor
struct ExpressionArithmeticTests {
  let db: Database

  init() throws {
    db = try Database.openInMemory()

    try db.exec(
      """
      CREATE TABLE sales (
          id INTEGER PRIMARY KEY,
          price REAL, discount REAL,
          quantity INTEGER,
          stock INTEGER
      )
      """
    )
    try prepareDatabase()
  }

  func prepareDatabase() throws {
    try db.exec(raw: "INSERT INTO sales (price, discount, quantity, stock) VALUES (100.0, 10.0, 2, 50)")
    try db.exec(raw: "INSERT INTO sales (price, discount, quantity, stock) VALUES (200.0, 20.0, 1, 30)")
    try db.exec(raw: "INSERT INTO sales (price, discount, quantity, stock) VALUES (150.0, 15.0, 3, 20)")
    try db.exec(raw: "INSERT INTO sales (price, discount, quantity, stock) VALUES (120.0, 5.0, 4, 40)")
  }

  let price = ColumnExpression<Double>("price")
  let discount = ColumnExpression<Double>("discount")
  let quantity = ColumnExpression<Int>("quantity")
  let stock = ColumnExpression<Int>("stock")

  private func run<E: LoomCore.Expression, T>(
    _ expression: E,
    expectedExpression: String,
    expectedValues: [T]
  ) throws where E.ExpressionValue == T, T: Bindable & Equatable {
    // Test SQL generation
    var builder = SQLBuilder()
    expression.append(to: &builder)
    #expect(builder.makeStatement().sql == expectedExpression)

    // Test query execution
    let result = try db.query(
      "SELECT \(expression) FROM sales ORDER BY id",
      stepper: { stmt, _ in
        try T.column(of: stmt, at: 0)
      }
    )
    #expect(result == expectedValues)
  }

  @Test("Integer addition operator")
  func testIntegerAdditionSQL() throws {
    try run(
      quantity + stock,
      expectedExpression: "( \"quantity\" + \"stock\" )",
      expectedValues: [52, 31, 23, 44]
    )
  }

  @Test("Real addition operator")
  func testRealAdditionSQL() throws {
    try run(
      price + discount,
      expectedExpression: "( \"price\" + \"discount\" )",
      expectedValues: [110.0, 220.0, 165.0, 125.0]
    )
  }

  @Test("Integer subtraction operator")
  func testIntegerSubtractionSQL() throws {
    try run(
      stock - quantity,
      expectedExpression: "( \"stock\" - \"quantity\" )",
      expectedValues: [48, 29, 17, 36]
    )
  }

  @Test("Real subtraction operator")
  func testRealSubtractionSQL() throws {
    try run(
      price - discount,
      expectedExpression: "( \"price\" - \"discount\" )",
      expectedValues: [90.0, 180.0, 135.0, 115.0]
    )
  }

  @Test("Integer multiplication operator")
  func testIntegerMultiplicationSQL() throws {
    try run(
      quantity * stock,
      expectedExpression: "( \"quantity\" * \"stock\" )",
      expectedValues: [100, 30, 60, 160]
    )
  }

  @Test("Real multiplication operator")
  func testRealMultiplicationSQL() throws {
    try run(
      price * discount,
      expectedExpression: "( \"price\" * \"discount\" )",
      expectedValues: [1000.0, 4000.0, 2250.0, 600.0]
    )
  }

  @Test("Integer division operator")
  func testIntegerDivisionSQL() throws {
    try run(
      stock / quantity,
      expectedExpression: "( \"stock\" / \"quantity\" )",
      expectedValues: [25, 30, 6, 10]
    )
  }

  @Test("Real division operator")
  func testRealDivisionSQL() throws {
    try run(
      price / discount,
      expectedExpression: "( \"price\" / \"discount\" )",
      expectedValues: [10.0, 10.0, 10.0, 24.0]
    )
  }

  @Test("Integer modulo operator")
  func testIntegerModuloSQL() throws {
    try run(
      stock % quantity,
      expectedExpression: "( \"stock\" % \"quantity\" )",
      expectedValues: [0, 0, 2, 0]
    )
  }

  @Test("Integer negation operator")
  func testIntegerNegationSQL() throws {
    try run(
      -quantity,
      expectedExpression: "( - \"quantity\" )",
      expectedValues: [-2, -1, -3, -4]
    )
  }

  @Test("Real negation operator")
  func testRealNegationSQL() throws {
    try run(
      -price,
      expectedExpression: "( - \"price\" )",
      expectedValues: [-100.0, -200.0, -150.0, -120.0]
    )
  }

  @Test("Integer complex expression")
  func testIntegerComplexExpressionSQL() throws {
    try run(
      (quantity + -stock) * 2 - 10,
      expectedExpression: "( ( ( \"quantity\" + ( - \"stock\" ) ) * ? ) - ? )",
      expectedValues: [-106, -68, -44, -82]
    )
  }

  @Test("Real complex expression")
  func testRealComplexExpressionSQL() throws {
    try run(
      (price + -discount) * 2 - 10,
      expectedExpression: "( ( ( \"price\" + ( - \"discount\" ) ) * ? ) - ? )",
      expectedValues: [170.0, 350.0, 260.0, 220.0]
    )
  }
}
