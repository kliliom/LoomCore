import Foundation
import LoomCore
import Testing

@Suite("Function GroupConcat Tests")
@DatabaseActor
struct FunctionGroupConcatTests {
  @Test("GroupConcat function")
  func testGroupConcat() async throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try await db.exec("CREATE TABLE tags (id INTEGER PRIMARY KEY, name TEXT)")

    // Insert test data
    try await db.exec(raw: "INSERT INTO tags (name) VALUES ('swift')")
    try await db.exec(raw: "INSERT INTO tags (name) VALUES ('ios')")
    try await db.exec(raw: "INSERT INTO tags (name) VALUES ('mobile')")

    // Test expression
    let expr = ColumnExpression<String>("name").groupConcat()

    // Query using GROUP_CONCAT function
    let result = try await db.query(
      "SELECT \(expr) FROM tags",
      stepper: { stmt, _ in
        try String?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == "swift,ios,mobile")
  }

  @Test("GroupConcat function with custom separator")
  func testGroupConcatCustomSeparator() async throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try await db.exec("CREATE TABLE tags (id INTEGER PRIMARY KEY, name TEXT)")

    // Insert test data
    try await db.exec(raw: "INSERT INTO tags (name) VALUES ('swift')")
    try await db.exec(raw: "INSERT INTO tags (name) VALUES ('ios')")
    try await db.exec(raw: "INSERT INTO tags (name) VALUES ('mobile')")

    // Test expression with custom separator
    let expr = ColumnExpression<String>("name").groupConcat(separator: " | ")

    // Query using GROUP_CONCAT function
    let result = try await db.query(
      "SELECT \(expr) FROM tags",
      stepper: { stmt, _ in
        try String?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == "swift | ios | mobile")
  }

  @Test("GroupConcat function with distinct")
  func testGroupConcatDistinct() async throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try await db.exec("CREATE TABLE tags (id INTEGER PRIMARY KEY, name TEXT)")

    // Insert test data with duplicates
    try await db.exec(raw: "INSERT INTO tags (name) VALUES ('swift')")
    try await db.exec(raw: "INSERT INTO tags (name) VALUES ('ios')")
    try await db.exec(raw: "INSERT INTO tags (name) VALUES ('swift')")
    try await db.exec(raw: "INSERT INTO tags (name) VALUES ('mobile')")

    // Test expression with distinct
    let expr = ColumnExpression<String>("name").groupConcat(distinct: true)

    // Query using GROUP_CONCAT function
    let result = try await db.query(
      "SELECT \(expr) FROM tags",
      stepper: { stmt, _ in
        try String?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == "swift,ios,mobile")
  }

  @Test("GroupConcat function with no rows")
  func testGroupConcatNoRows() async throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try await db.exec("CREATE TABLE tags (id INTEGER PRIMARY KEY, name TEXT)")

    // Test expression
    let expr = ColumnExpression<String>("name").groupConcat()

    // Query using GROUP_CONCAT function
    let result = try await db.query(
      "SELECT \(expr) FROM tags",
      stepper: { stmt, _ in
        try String?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == nil)
  }

  @Test("GroupConcat ExpressionValue is optional String")
  func testGroupConcatExpressionValueIsOptional() {
    #expect(GroupConcat.ExpressionValue.self == String?.self)
  }

  // SQLite rejects GROUP_CONCAT(DISTINCT expr, sep) at runtime; the distinct
  // initializer takes no separator, so this pins the only SQL it can render.
  @Test("GroupConcat with distinct renders without a separator argument")
  func testGroupConcatDistinctRendering() {
    let expr = GroupConcat(ColumnExpression<String>("name"), distinct: true)
    var builder = SQLBuilder()
    expr.append(to: &builder)
    #expect(builder.makeStatement().sql == "GROUP_CONCAT( DISTINCT  \"name\" )")
  }
}
