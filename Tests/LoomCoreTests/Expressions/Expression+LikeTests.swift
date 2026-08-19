import Foundation
import LoomCore
import Testing

@Suite("Expression String Tests")
@DatabaseActor
struct ExpressionStringTests {
  let db: Database

  init() async throws {
    db = try Database.openInMemory()
    try await db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, username TEXT, email TEXT)")
    try await prepareDatabase()
  }

  func prepareDatabase() async throws {
    try await db.exec(raw: "INSERT INTO users (username, email) VALUES ('admin', 'admin@example.com')")
    try await db.exec(raw: "INSERT INTO users (username, email) VALUES ('user_123', 'user@example.com')")
    try await db.exec(raw: "INSERT INTO users (username, email) VALUES ('user123', 'guest@test.com')")
    try await db.exec(raw: "INSERT INTO users (username, email) VALUES ('moderator', 'mod@example.com')")
  }

  let username = ColumnExpression<String>("username")
  let email = ColumnExpression<String>("email")

  func run<E: LoomCore.Expression, T>(
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
      "SELECT \(expression) FROM users ORDER BY id",
      stepper: { stmt, _ in
        try T.column(of: stmt, at: 0)
      }
    )
    #expect(result == expectedValues)
  }

  @Test("LIKE operator with wildcard")
  func testLikeWithWildcard() async throws {
    try await run(
      username.like("%user%"),
      expectedExpression: "( \"username\" LIKE ? )",
      expectedValues: [false, true, true, false]
    )
  }

  @Test("LIKE operator with single character wildcard")
  func testLikeWithSingleCharacterWildcard() async throws {
    try await run(
      username.like("u_er%"),
      expectedExpression: "( \"username\" LIKE ? )",
      expectedValues: [false, true, true, false]
    )
  }

  @Test("LIKE operator with no wildcard")
  func testLikeWithNoWildcard() async throws {
    try await run(
      username.like("admin"),
      expectedExpression: "( \"username\" LIKE ? )",
      expectedValues: [true, false, false, false]
    )
  }

  @Test("LIKE operator with special characters")
  func testLikeWithSpecialCharacters() async throws {
    try await run(
      email.like("%@example.com"),
      expectedExpression: "( \"email\" LIKE ? )",
      expectedValues: [true, true, false, true]
    )
  }

  @Test("LIKE operator with escape character")
  func testLikeWithEscapeCharacter() async throws {
    try await run(
      username.like("user\\_%", escape: "\\"),
      expectedExpression: "( \"username\" LIKE ? ESCAPE '\\' )",
      expectedValues: [false, true, false, false]
    )
  }

  @Test("NOT LIKE operator with wildcard")
  func testNotLikeWithWildcard() async throws {
    try await run(
      username.notLike("%user%"),
      expectedExpression: "( \"username\" NOT LIKE ? )",
      expectedValues: [true, false, false, true]
    )
  }

  @Test("NOT LIKE operator with single character wildcard")
  func testNotLikeWithSingleCharacterWildcard() async throws {
    try await run(
      username.notLike("u_er%"),
      expectedExpression: "( \"username\" NOT LIKE ? )",
      expectedValues: [true, false, false, true]
    )
  }

  @Test("NOT LIKE operator with no wildcard")
  func testNotLikeWithNoWildcard() async throws {
    try await run(
      username.notLike("admin"),
      expectedExpression: "( \"username\" NOT LIKE ? )",
      expectedValues: [false, true, true, true]
    )
  }

  @Test("NOT LIKE operator with special characters")
  func testNotLikeWithSpecialCharacters() async throws {
    try await run(
      email.notLike("%@example.com"),
      expectedExpression: "( \"email\" NOT LIKE ? )",
      expectedValues: [false, false, true, false]
    )
  }

  @Test("NOT LIKE operator with escape character")
  func testNotLikeWithEscapeCharacter() async throws {
    try await run(
      username.notLike("user\\_%", escape: "\\"),
      expectedExpression: "( \"username\" NOT LIKE ? ESCAPE '\\' )",
      expectedValues: [true, false, true, true]
    )
  }
}
