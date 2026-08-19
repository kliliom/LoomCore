import Foundation
import LoomCore
import Testing

@Suite("IfNullExpression Tests")
@DatabaseActor
struct IfNullExpressionTests {
  let db: Database

  init() async throws {
    db = try Database.openInMemory()
    try await db.exec("CREATE TABLE products (id INTEGER PRIMARY KEY, price REAL)")
    try await prepareDatabase()
  }

  func prepareDatabase() async throws {
    try await db.exec(raw: "INSERT INTO products (price) VALUES (10.0)")
    try await db.exec(raw: "INSERT INTO products (price) VALUES (20.0)")
    try await db.exec(raw: "INSERT INTO products (price) VALUES (NULL)")
    try await db.exec(raw: "INSERT INTO products (price) VALUES (NULL)")
  }

  let price = ColumnExpression<Double?>("price")

  func run<E: LoomCore.Expression, T>(
    _ expression: E,
    expectedExpression: String,
    expectedValues: [T?]
  ) async throws where E.ExpressionValue == T, T: Bindable & Equatable {
    // Test SQL generation
    var builder = SQLBuilder()
    expression.append(to: &builder)
    #expect(builder.makeStatement().sql == expectedExpression)

    // Test query execution
    let result = try await db.query(
      "SELECT \(expression) FROM products ORDER BY id",
      stepper: { stmt, _ in
        try T?.column(of: stmt, at: 0)
      }
    )
    #expect(result == expectedValues)
  }

  @Test("IFNULL operator with non-null values")
  func testIfNullWithNonNullValues() async throws {
    try await run(
      price.ifNull(0.0),
      expectedExpression: "IFNULL( \"price\" , ? )",
      expectedValues: [10.0, 20.0, 0.0, 0.0]
    )
  }
}
