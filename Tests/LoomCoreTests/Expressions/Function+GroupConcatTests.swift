import Foundation
import LoomCore
import Testing

@Suite("Function GroupConcat Tests")
@DatabaseActor
struct FunctionGroupConcatTests {
  @Test("GroupConcat function")
  func testGroupConcat() throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try db.exec("CREATE TABLE tags (id INTEGER PRIMARY KEY, name TEXT)")

    // Insert test data
    try db.exec(raw: "INSERT INTO tags (name) VALUES ('swift')")
    try db.exec(raw: "INSERT INTO tags (name) VALUES ('ios')")
    try db.exec(raw: "INSERT INTO tags (name) VALUES ('mobile')")

    // Test expression
    let expr = ColumnExpression<String>("name").groupConcat()

    // Query using GROUP_CONCAT function
    let result = try db.query(
      "SELECT \(expr) FROM tags",
      stepper: { stmt, _ in
        try String?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == "swift,ios,mobile")
  }

  @Test("GroupConcat function with custom separator")
  func testGroupConcatCustomSeparator() throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try db.exec("CREATE TABLE tags (id INTEGER PRIMARY KEY, name TEXT)")

    // Insert test data
    try db.exec(raw: "INSERT INTO tags (name) VALUES ('swift')")
    try db.exec(raw: "INSERT INTO tags (name) VALUES ('ios')")
    try db.exec(raw: "INSERT INTO tags (name) VALUES ('mobile')")

    // Test expression with custom separator
    let expr = ColumnExpression<String>("name").groupConcat(separator: " | ")

    // Query using GROUP_CONCAT function
    let result = try db.query(
      "SELECT \(expr) FROM tags",
      stepper: { stmt, _ in
        try String?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == "swift | ios | mobile")
  }

  @Test("GroupConcat function with distinct")
  func testGroupConcatDistinct() throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try db.exec("CREATE TABLE tags (id INTEGER PRIMARY KEY, name TEXT)")

    // Insert test data with duplicates
    try db.exec(raw: "INSERT INTO tags (name) VALUES ('swift')")
    try db.exec(raw: "INSERT INTO tags (name) VALUES ('ios')")
    try db.exec(raw: "INSERT INTO tags (name) VALUES ('swift')")
    try db.exec(raw: "INSERT INTO tags (name) VALUES ('mobile')")

    // Test expression with distinct
    let expr = ColumnExpression<String>("name").groupConcat(distinct: true)

    // Query using GROUP_CONCAT function
    let result = try db.query(
      "SELECT \(expr) FROM tags",
      stepper: { stmt, _ in
        try String?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 1)
    #expect(result[0] == "swift,ios,mobile")
  }

  @Test("GroupConcat function with no rows")
  func testGroupConcatNoRows() throws {
    let db = try Database.openInMemory()

    // Create a table with text data
    try db.exec("CREATE TABLE tags (id INTEGER PRIMARY KEY, name TEXT)")

    // Test expression
    let expr = ColumnExpression<String>("name").groupConcat()

    // Query using GROUP_CONCAT function
    let result = try db.query(
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
}
