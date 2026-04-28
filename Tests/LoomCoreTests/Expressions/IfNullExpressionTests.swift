import Foundation
import LoomCore
import Testing

@Suite("IfNullExpression Tests")
@DatabaseActor
struct IfNullExpressionTests {
  let db: Database

  init() throws {
    db = try Database.openInMemory()
    try db.exec("CREATE TABLE products (id INTEGER PRIMARY KEY, price REAL)")
    try prepareDatabase()
  }

  func prepareDatabase() throws {
    try db.exec(raw: "INSERT INTO products (price) VALUES (10.0)")
    try db.exec(raw: "INSERT INTO products (price) VALUES (20.0)")
    try db.exec(raw: "INSERT INTO products (price) VALUES (NULL)")
    try db.exec(raw: "INSERT INTO products (price) VALUES (NULL)")
  }

  let price = ColumnExpression<Double?>("price")

  func run<E: LoomCore.Expression, T>(
    _ expression: E,
    expectedExpression: String,
    expectedValues: [T?]
  ) throws where E.ExpressionValue == T, T: Bindable & Equatable {
    // Test SQL generation
    var builder = SQLBuilder()
    expression.append(to: &builder)
    #expect(builder.makeStatement().sql == expectedExpression)

    // Test query execution
    let result = try db.query(
      "SELECT \(expression) FROM products ORDER BY id",
      stepper: { stmt, _ in
        try T?.column(of: stmt, at: 0)
      }
    )
    #expect(result == expectedValues)
  }

  @Test("IFNULL operator with non-null values")
  func testIfNullWithNonNullValues() throws {
    try run(
      price.ifNull(0.0),
      expectedExpression: "IFNULL( \"price\" , ? )",
      expectedValues: [10.0, 20.0, 0.0, 0.0]
    )
  }
}
