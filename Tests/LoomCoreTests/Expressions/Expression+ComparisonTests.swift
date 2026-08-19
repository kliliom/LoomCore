import Foundation
import LoomCore
import Testing

@Suite("Expression Comparison Tests")
@DatabaseActor
struct ExpressionComparisonTests {
  let db: Database

  init() async throws {
    db = try Database.openInMemory()
    try await db.exec("CREATE TABLE people (id INTEGER PRIMARY KEY, name TEXT, age INTEGER, score REAL)")
    try await prepareDatabase()
  }

  func prepareDatabase() async throws {
    try await db.exec(raw: "INSERT INTO people (name, age, score) VALUES ('Alice', 25, 85.5)")
    try await db.exec(raw: "INSERT INTO people (name, age, score) VALUES ('Bob', 30, 92.0)")
    try await db.exec(raw: "INSERT INTO people (name, age, score) VALUES ('Charlie', 20, 78.5)")
    try await db.exec(raw: "INSERT INTO people (name, age, score) VALUES ('Diana', 25, 88.0)")
  }

  let name = ColumnExpression<String>("name")
  let age = ColumnExpression<Int>("age")
  let score = ColumnExpression<Double>("score")

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

  @Test("String equality operator")
  func testStringEqualitySQL() async throws {
    try await run(
      name == "Alice",
      expectedExpression: "( \"name\" = ? )",
      expectedValues: [true, false, false, false]
    )
  }

  @Test("Integer equality operator")
  func testIntegerEqualitySQL() async throws {
    try await run(
      age == 25,
      expectedExpression: "( \"age\" = ? )",
      expectedValues: [true, false, false, true]
    )
  }

  @Test("Real equality operator")
  func testRealEqualitySQL() async throws {
    try await run(
      score == 85.5,
      expectedExpression: "( \"score\" = ? )",
      expectedValues: [true, false, false, false]
    )
  }

  @Test("String inequality operator")
  func testStringInequalitySQL() async throws {
    try await run(
      name != "Alice",
      expectedExpression: "( \"name\" <> ? )",
      expectedValues: [false, true, true, true]
    )
  }

  @Test("Integer inequality operator")
  func testIntegerInequalitySQL() async throws {
    try await run(
      age != 25,
      expectedExpression: "( \"age\" <> ? )",
      expectedValues: [false, true, true, false]
    )
  }

  @Test("Real inequality operator")
  func testRealInequalitySQL() async throws {
    try await run(
      score != 85.5,
      expectedExpression: "( \"score\" <> ? )",
      expectedValues: [false, true, true, true]
    )
  }

  @Test("String less than operator")
  func testStringLessThanSQL() async throws {
    try await run(
      name < "Charlie",
      expectedExpression: "( \"name\" < ? )",
      expectedValues: [true, true, false, false]
    )
  }

  @Test("Integer less than operator")
  func testIntegerLessThanSQL() async throws {
    try await run(
      age < 25,
      expectedExpression: "( \"age\" < ? )",
      expectedValues: [false, false, true, false]
    )
  }

  @Test("Real less than operator")
  func testRealLessThanSQL() async throws {
    try await run(
      score < 85.5,
      expectedExpression: "( \"score\" < ? )",
      expectedValues: [false, false, true, false]
    )
  }

  @Test("String less than equal operator")
  func testStringLessThanEqualSQL() async throws {
    try await run(
      name <= "Charlie",
      expectedExpression: "( \"name\" <= ? )",
      expectedValues: [true, true, true, false]
    )
  }

  @Test("Integer less than equal operator")
  func testIntegerLessThanEqualSQL() async throws {
    try await run(
      age <= 25,
      expectedExpression: "( \"age\" <= ? )",
      expectedValues: [true, false, true, true]
    )
  }

  @Test("Real less than equal operator")
  func testRealLessThanEqualSQL() async throws {
    try await run(
      score <= 85.5,
      expectedExpression: "( \"score\" <= ? )",
      expectedValues: [true, false, true, false]
    )
  }

  @Test("String greater than operator")
  func testStringGreaterThanSQL() async throws {
    try await run(
      name > "Charlie",
      expectedExpression: "( \"name\" > ? )",
      expectedValues: [false, false, false, true]
    )
  }

  @Test("Integer greater than operator")
  func testIntegerGreaterThanSQL() async throws {
    try await run(
      age > 25,
      expectedExpression: "( \"age\" > ? )",
      expectedValues: [false, true, false, false]
    )
  }

  @Test("Real greater than operator")
  func testRealGreaterThanSQL() async throws {
    try await run(
      score > 85.5,
      expectedExpression: "( \"score\" > ? )",
      expectedValues: [false, true, false, true]
    )
  }

  @Test("String greater than or equal operator")
  func testStringGreaterThanEqualSQL() async throws {
    try await run(
      name >= "Charlie",
      expectedExpression: "( \"name\" >= ? )",
      expectedValues: [false, false, true, true]
    )
  }

  @Test("Integer greater than or equal operator")
  func testIntegerGreaterThanEqualSQL() async throws {
    try await run(
      age >= 25,
      expectedExpression: "( \"age\" >= ? )",
      expectedValues: [true, true, false, true]
    )
  }

  @Test("Real greater than or equal operator")
  func testRealGreaterThanEqualSQL() async throws {
    try await run(
      score >= 85.5,
      expectedExpression: "( \"score\" >= ? )",
      expectedValues: [true, true, false, true]
    )
  }

  // MARK: - Mixed Optionality

  @Test("Optional-valued function compares against a literal")
  func testOptionalLhsAgainstLiteral() async throws {
    try await run(
      name.length() > 3,
      expectedExpression: "( LENGTH( \"name\" ) > ? )",
      expectedValues: [true, false, true, true]
    )
  }

  @Test("Optional-valued function equality against a literal")
  func testOptionalLhsEquality() async throws {
    try await run(
      name.lower() == "alice",
      expectedExpression: "( LOWER( \"name\" ) = ? )",
      expectedValues: [true, false, false, false]
    )
  }

  @Test("Non-optional expression compares against an optional-valued function")
  func testNonOptionalLhsAgainstOptionalRhs() async throws {
    try await run(
      3 < name.length(),
      expectedExpression: "( ? < LENGTH( \"name\" ) )",
      expectedValues: [true, false, true, true]
    )
  }

  @Test("Optional-valued aggregate comparison in HAVING")
  func testAggregateComparisonInHaving() async throws {
    let totals = try await db.query(
      "SELECT \(score.sum()) FROM people GROUP BY \(age) HAVING \(score.sum() >= 100.0)",
      stepper: { stmt, _ in
        try Double?.column(of: stmt, at: 0)
      }
    )
    #expect(totals == [173.5])
  }

  @Test("Two optional-valued aggregates compare against each other")
  func testOptionalAgainstOptional() async throws {
    let rows = try await db.query(
      "SELECT \(age.min() < age.max()) FROM people",
      stepper: { stmt, _ in
        try Bool.column(of: stmt, at: 0)
      }
    )
    #expect(rows == [true])
  }
}
