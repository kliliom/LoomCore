import Foundation
import Testing

@testable import LoomCore

@Suite("SQLBuilder Tests")
struct SQLBuilderTests {
  @Test("SQLBuilder append literal")
  func testAppendLiteral() {
    var builder = SQLBuilder()
    builder.appendLiteral("SELECT * FROM users")

    #expect(builder.sql.count == 1)
    #expect(builder.sql[0] == "SELECT * FROM users")
    #expect(builder.binders.isEmpty)
  }

  @Test("SQLBuilder append interpolation in bind mode")
  func testAppendInterpolationBindMode() {
    var builder = SQLBuilder()
    builder.appendLiteral("SELECT * FROM users WHERE name = ")
    builder.appendInterpolation("Alice", mode: .bind)

    #expect(builder.sql.count == 2)
    #expect(builder.sql[1] == "?")
    #expect(builder.binders.count == 1)
  }

  @Test("SQLBuilder append interpolation in raw mode")
  func testAppendInterpolationRawMode() {
    var builder = SQLBuilder()
    builder.appendLiteral("SELECT * FROM ")
    builder.appendInterpolation("users", mode: .raw)

    #expect(builder.sql.count == 2)
    #expect(builder.sql[1] == "users")
    #expect(builder.binders.isEmpty)
  }

  @Test("SQLBuilder makes statement")
  func testMakeStatement() {
    var builder = SQLBuilder()
    builder.appendLiteral("SELECT * FROM users WHERE name = ")
    builder.appendInterpolation("Alice", mode: .bind)

    let stmt = builder.makeStatement()

    #expect(stmt.sql.contains("?"))
    #expect(stmt.binders.count == 1)
  }

  @Test("SQLBuilder with multiple interpolations")
  func testMultipleInterpolations() {
    var builder = SQLBuilder()
    builder.appendLiteral("SELECT * FROM users WHERE name = ")
    builder.appendInterpolation("Alice", mode: .bind)
    builder.appendLiteral(" AND age = ")
    builder.appendInterpolation(25, mode: .bind)

    let stmt = builder.makeStatement()

    #expect(stmt.binders.count == 2)
  }

  @Test("SQLBuilder with capacity hints")
  func testBuilderWithCapacityHints() {
    let builder = SQLBuilder(literalCapacity: 10, interpolationCount: 5)

    // Should pre-allocate space
    #expect(builder.sql.capacity >= 5)
    #expect(builder.binders.capacity >= 5)
  }

  @Test("SQLBuilder append different types")
  func testAppendDifferentTypes() {
    var builder = SQLBuilder()
    builder.appendLiteral("INSERT INTO test VALUES (")
    builder.appendInterpolation("string", mode: .bind)
    builder.appendLiteral(", ")
    builder.appendInterpolation(42, mode: .bind)
    builder.appendLiteral(", ")
    builder.appendInterpolation(3.14, mode: .bind)
    builder.appendLiteral(", ")
    builder.appendInterpolation(true, mode: .bind)
    builder.appendLiteral(")")

    let stmt = builder.makeStatement()

    #expect(stmt.binders.count == 4)
  }

  @Test("SQLBuilder with optional values")
  func testBuilderWithOptionals() {
    var builder = SQLBuilder()
    builder.appendLiteral("INSERT INTO test VALUES (")

    let optionalValue: String? = nil
    builder.appendInterpolation(optionalValue, mode: .bind)
    builder.appendLiteral(")")

    let stmt = builder.makeStatement()

    #expect(stmt.binders.count == 1)
  }

  @Test("SQLBuilder empty builder")
  func testEmptyBuilder() {
    let builder = SQLBuilder()

    #expect(builder.sql.isEmpty)
    #expect(builder.binders.isEmpty)
  }

  @Test("SQLBuilder raw mode with string")
  func testRawModeWithString() {
    var builder = SQLBuilder()
    builder.appendLiteral("SELECT * FROM ")
    builder.appendInterpolation("my_table", mode: .raw)
    builder.appendLiteral(" WHERE id = ")
    builder.appendInterpolation(1, mode: .bind)

    let stmt = builder.makeStatement()
    let sql = stmt.sql

    #expect(sql.contains("my_table"))
    #expect(!sql.contains("my_table") || sql.range(of: "\\?.*my_table", options: .regularExpression) == nil)
    #expect(stmt.binders.count == 1)
  }

  @Test("SQLBuilder combined with SQLStatement")
  @DatabaseActor
  func testBuilderWithDatabase() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    var builder = SQLBuilder()
    builder.appendLiteral("INSERT INTO users (name, age) VALUES (")
    builder.appendInterpolation("Alice", mode: .bind)
    builder.appendLiteral(", ")
    builder.appendInterpolation(25, mode: .bind)
    builder.appendLiteral(")")

    let stmt = builder.makeStatement()
    try await db.exec(stmt)

    let result = try await db.query("SELECT name, age FROM users") { stmt, _ in
      let name = try String.column(of: stmt, at: 0)
      let age = try Int.column(of: stmt, at: 1)
      return (name, age)
    }

    #expect(result.first?.0 == "Alice")
    #expect(result.first?.1 == 25)
  }
}
