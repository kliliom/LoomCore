import Foundation
import LoomCore
import Testing

@Suite("Expression Logical Tests")
@DatabaseActor
struct ExpressionLogicalTests {
  let db: Database

  init() async throws {
    db = try Database.openInMemory()
    try await db.exec("CREATE TABLE people (id INTEGER PRIMARY KEY, name TEXT, age INTEGER, active INTEGER)")
    try await prepareDatabase()
  }

  func prepareDatabase() async throws {
    try await db.exec(raw: "INSERT INTO people (name, age, active) VALUES ('Alice', 25, 1)")
    try await db.exec(raw: "INSERT INTO people (name, age, active) VALUES ('Bob', 30, 0)")
    try await db.exec(raw: "INSERT INTO people (name, age, active) VALUES ('Charlie', 20, 1)")
    try await db.exec(raw: "INSERT INTO people (name, age, active) VALUES ('Diana', 35, 1)")
  }

  let name = ColumnExpression<String>("name")
  let age = ColumnExpression<Int>("age")
  let active = ColumnExpression<Int>("active")

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
      "SELECT \(expression) FROM people ORDER BY id",
      stepper: { stmt, _ in
        try T.column(of: stmt, at: 0)
      }
    )
    #expect(result == expectedValues)
  }

  @Test("Logical AND operator")
  func testLogicalANDSQL() async throws {
    try await run(
      (age > 25) && (active == 1),
      expectedExpression: "( ( \"age\" > ? ) AND ( \"active\" = ? ) )",
      expectedValues: [false, false, false, true]
    )
  }

  @Test("Logical OR operator")
  func testLogicalORSQL() async throws {
    try await run(
      (age < 25) || (active == 0),
      expectedExpression: "( ( \"age\" < ? ) OR ( \"active\" = ? ) )",
      expectedValues: [false, true, true, false]
    )
  }

  @Test("Logical NOT operator")
  func testLogicalNOTSQL() async throws {
    try await run(
      !(active == 1),
      expectedExpression: "( NOT ( \"active\" = ? ) )",
      expectedValues: [false, true, false, false]
    )
  }
}
