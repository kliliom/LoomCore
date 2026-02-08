import Foundation
import LoomCore
import Testing

@Suite("Expression Comparison Tests")
@DatabaseActor
struct ExpressionComparisonTests {
  let db: Database

  init() throws {
    db = try Database.openInMemory()
    try db.exec("CREATE TABLE people (id INTEGER PRIMARY KEY, name TEXT, age INTEGER, score REAL)")
    try prepareDatabase()
  }

  func prepareDatabase() throws {
    try db.exec(raw: "INSERT INTO people (name, age, score) VALUES ('Alice', 25, 85.5)")
    try db.exec(raw: "INSERT INTO people (name, age, score) VALUES ('Bob', 30, 92.0)")
    try db.exec(raw: "INSERT INTO people (name, age, score) VALUES ('Charlie', 20, 78.5)")
    try db.exec(raw: "INSERT INTO people (name, age, score) VALUES ('Diana', 25, 88.0)")
  }

  let name = ColumnExpression<String>("name")
  let age = ColumnExpression<Int>("age")
  let score = ColumnExpression<Double>("score")

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
      "SELECT \(expression) FROM people ORDER BY id",
      stepper: { stmt, _ in
        try T.column(of: stmt, at: 0)
      }
    )
    #expect(result == expectedValues)
  }

  @Test("String equality operator")
  func testStringEqualitySQL() throws {
    try run(
      name == "Alice",
      expectedExpression: "( name = ? )",
      expectedValues: [true, false, false, false]
    )
  }

  @Test("Integer equality operator")
  func testIntegerEqualitySQL() throws {
    try run(
      age == 25,
      expectedExpression: "( age = ? )",
      expectedValues: [true, false, false, true]
    )
  }

  @Test("Real equality operator")
  func testRealEqualitySQL() throws {
    try run(
      score == 85.5,
      expectedExpression: "( score = ? )",
      expectedValues: [true, false, false, false]
    )
  }

  @Test("String inequality operator")
  func testStringInequalitySQL() throws {
    try run(
      name != "Alice",
      expectedExpression: "( name <> ? )",
      expectedValues: [false, true, true, true]
    )
  }

  @Test("Integer inequality operator")
  func testIntegerInequalitySQL() throws {
    try run(
      age != 25,
      expectedExpression: "( age <> ? )",
      expectedValues: [false, true, true, false]
    )
  }

  @Test("Real inequality operator")
  func testRealInequalitySQL() throws {
    try run(
      score != 85.5,
      expectedExpression: "( score <> ? )",
      expectedValues: [false, true, true, true]
    )
  }

  @Test("String less than operator")
  func testStringLessThanSQL() throws {
    try run(
      name < "Charlie",
      expectedExpression: "( name < ? )",
      expectedValues: [true, true, false, false]
    )
  }

  @Test("Integer less than operator")
  func testIntegerLessThanSQL() throws {
    try run(
      age < 25,
      expectedExpression: "( age < ? )",
      expectedValues: [false, false, true, false]
    )
  }

  @Test("Real less than operator")
  func testRealLessThanSQL() throws {
    try run(
      score < 85.5,
      expectedExpression: "( score < ? )",
      expectedValues: [false, false, true, false]
    )
  }

  @Test("String less than equal operator")
  func testStringLessThanEqualSQL() throws {
    try run(
      name <= "Charlie",
      expectedExpression: "( name <= ? )",
      expectedValues: [true, true, true, false]
    )
  }

  @Test("Integer less than equal operator")
  func testIntegerLessThanEqualSQL() throws {
    try run(
      age <= 25,
      expectedExpression: "( age <= ? )",
      expectedValues: [true, false, true, true]
    )
  }

  @Test("Real less than equal operator")
  func testRealLessThanEqualSQL() throws {
    try run(
      score <= 85.5,
      expectedExpression: "( score <= ? )",
      expectedValues: [true, false, true, false]
    )
  }

  @Test("String greater than operator")
  func testStringGreaterThanSQL() throws {
    try run(
      name > "Charlie",
      expectedExpression: "( name > ? )",
      expectedValues: [false, false, false, true]
    )
  }

  @Test("Integer greater than operator")
  func testIntegerGreaterThanSQL() throws {
    try run(
      age > 25,
      expectedExpression: "( age > ? )",
      expectedValues: [false, true, false, false]
    )
  }

  @Test("Real greater than operator")
  func testRealGreaterThanSQL() throws {
    try run(
      score > 85.5,
      expectedExpression: "( score > ? )",
      expectedValues: [false, true, false, true]
    )
  }

  @Test("String greater than or equal operator")
  func testStringGreaterThanEqualSQL() throws {
    try run(
      name >= "Charlie",
      expectedExpression: "( name >= ? )",
      expectedValues: [false, false, true, true]
    )
  }

  @Test("Integer greater than or equal operator")
  func testIntegerGreaterThanEqualSQL() throws {
    try run(
      age >= 25,
      expectedExpression: "( age >= ? )",
      expectedValues: [true, true, false, true]
    )
  }

  @Test("Real greater than or equal operator")
  func testRealGreaterThanEqualSQL() throws {
    try run(
      score >= 85.5,
      expectedExpression: "( score >= ? )",
      expectedValues: [true, true, false, true]
    )
  }
}
