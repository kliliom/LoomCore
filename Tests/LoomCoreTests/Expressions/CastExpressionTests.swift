import Foundation
import LoomCore
import Testing

@Suite("CastExpression Tests")
@DatabaseActor
struct CastExpressionTests {
  let db: Database

  init() async throws {
    db = try Database.openInMemory()
    try await db.exec("CREATE TABLE data (id INTEGER PRIMARY KEY, text_value TEXT, int_value INTEGER, real_value REAL)")
    try await prepareDatabase()
  }

  func prepareDatabase() async throws {
    try await db.exec(raw: "INSERT INTO data (text_value, int_value, real_value) VALUES ('123', 123, 123.45)")
    try await db.exec(raw: "INSERT INTO data (text_value, int_value, real_value) VALUES ('456', 456, 456.78)")
    try await db.exec(raw: "INSERT INTO data (text_value, int_value, real_value) VALUES ('abc', 789, 789.01)")
  }

  let textValue = ColumnExpression<String>("text_value")
  let intValue = ColumnExpression<Int>("int_value")
  let realValue = ColumnExpression<Double>("real_value")

  private func run<E: LoomCore.Expression, T>(
    _ expression: E,
    expectedExpression: String,
    expectedValues: [T]
  ) async throws where E.ExpressionValue == T, T: Bindable & Equatable {
    // Test SQL generation
    var builder = SQLBuilder()
    expression.append(to: &builder)
    #expect(builder.makeStatement().sql == expectedExpression)

    // Test query execution
    let result = try await db.query(
      "SELECT \(expression) FROM data ORDER BY id",
      stepper: { stmt, _ in
        try T.column(of: stmt, at: 0)
      }
    )
    #expect(result == expectedValues)
  }

  @Test("Cast text to integer")
  func testCastTextToInteger() async throws {
    try await run(
      textValue.cast(to: Int.self),
      expectedExpression: "CAST( \"text_value\" AS INTEGER)",
      expectedValues: [123, 456, 0]
    )
  }

  @Test("Cast text to real")
  func testCastTextToReal() async throws {
    try await run(
      textValue.cast(to: Double.self),
      expectedExpression: "CAST( \"text_value\" AS DOUBLE)",
      expectedValues: [123.0, 456.0, 0.0]
    )
  }

  @Test("Cast integer to text")
  func testCastIntegerToText() async throws {
    try await run(
      intValue.cast(to: String.self),
      expectedExpression: "CAST( \"int_value\" AS TEXT)",
      expectedValues: ["123", "456", "789"]
    )
  }

  @Test("Cast real to integer")
  func testCastRealToInteger() async throws {
    try await run(
      realValue.cast(to: Int.self),
      expectedExpression: "CAST( \"real_value\" AS INTEGER)",
      expectedValues: [123, 456, 789]
    )
  }
}
