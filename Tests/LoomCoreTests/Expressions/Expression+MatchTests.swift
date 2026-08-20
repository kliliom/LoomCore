import Foundation
import LoomCore
import Testing

@Suite("Expression Match Tests")
@DatabaseActor
struct ExpressionMatchTests {
  let db: Database

  init() async throws {
    db = try Database.openInMemory()
    try await db.exec("CREATE VIRTUAL TABLE articles USING fts5(title, body)")
    try await db.exec(
      raw: "INSERT INTO articles (title, body) VALUES ('Swift Concurrency', 'Actors and tasks in swift explained')"
    )
    try await db.exec(
      raw: "INSERT INTO articles (title, body) VALUES ('Database Design', 'A fast sqlite wrapper for swift apps')"
    )
    try await db.exec(raw: "INSERT INTO articles (title, body) VALUES ('Cooking Pasta', 'Boil water and add salt')")
  }

  let articles = FTS5Table("articles", columns: ["title", "body"])
  let title = ColumnExpression<String>("title")

  func titles(where predicate: some LoomCore.Expression<Bool>) async throws -> [String] {
    try await db.query(
      "SELECT title FROM articles WHERE \(predicate) ORDER BY rowid",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )
  }

  @Test("Table match renders MATCH with a bound query")
  func testTableMatchSQL() {
    var builder = SQLBuilder()
    articles.match("swift").append(to: &builder)
    #expect(builder.makeStatement().sql == #"( "articles" MATCH ? )"#)
  }

  @Test("Column match renders the column identifier")
  func testColumnMatchSQL() {
    var builder = SQLBuilder()
    title.match("swift").append(to: &builder)
    #expect(builder.makeStatement().sql == #"( "title" MATCH ? )"#)
  }

  @Test("FTS5Query overload binds the rendered query text")
  func testQueryOverloadSQL() {
    var builder = SQLBuilder()
    articles.match(.phrase("swift")).append(to: &builder)
    let statement = builder.makeStatement()
    #expect(statement.sql == #"( "articles" MATCH ? )"#)
    #expect(statement.binders.count == 1)
  }

  @Test("Raw string match searches all indexed columns")
  func testRawStringExecution() async throws {
    #expect(try await titles(where: articles.match("swift")) == ["Swift Concurrency", "Database Design"])
  }

  @Test("Raw tokens match anywhere; a phrase requires adjacency")
  func testRawVersusPhraseSemantics() async throws {
    // "swift" and "actors" both appear in row 1, but never adjacently.
    #expect(try await titles(where: articles.match("swift actors")) == ["Swift Concurrency"])
    #expect(try await titles(where: articles.match(.phrase("swift actors"))) == [])
  }

  @Test("Typed query match executes like its raw rendering")
  func testQueryOverloadExecution() async throws {
    #expect(try await titles(where: articles.match(.prefix("data"))) == ["Database Design"])
  }

  @Test("Column match searches only that column")
  func testColumnMatchExecution() async throws {
    #expect(try await titles(where: title.match("swift")) == ["Swift Concurrency"])
    #expect(try await titles(where: title.match(.phrase("cooking pasta"))) == ["Cooking Pasta"])
  }

  @Test("Qualified column match renders and executes")
  func testQualifiedColumnMatch() async throws {
    let qualified = ColumnExpression<String>("title", of: "articles")

    var builder = SQLBuilder()
    qualified.match("swift").append(to: &builder)
    #expect(builder.makeStatement().sql == #"( "articles"."title" MATCH ? )"#)

    #expect(try await titles(where: qualified.match("swift")) == ["Swift Concurrency"])
  }

  @Test("A whole-table raw match grants the searcher column filters over every indexed column")
  func testRawQueryGrantsColumnFilters() async throws {
    // Binding prevents SQL injection but does not sandbox FTS5's own grammar: user-typed
    // query text can probe any indexed column, including ones the UI never renders.
    #expect(try await titles(where: articles.match("body : boil")) == ["Cooking Pasta"])
    #expect(try await titles(where: articles.match("body : missingword")) == [])
  }

  @Test("A column-scoped match cannot be widened by an inner column filter")
  func testColumnMatchConfinement() async throws {
    // "boil" appears only in the body; a body filter smuggled into a title-scoped match
    // stays confined to the title column and matches nothing.
    #expect(try await titles(where: title.match("body : boil")) == [])
  }

  @Test("Invalid raw query syntax throws at execution")
  func testInvalidSyntaxThrows() async throws {
    await #expect(throws: LoomError.self) {
      _ = try await titles(where: articles.match("AND"))
    }
  }

  @Test("MATCH composes with AND")
  func testMatchComposesWithAnd() async throws {
    let predicate = articles.match("swift") && title == "Swift Concurrency"
    #expect(try await titles(where: predicate) == ["Swift Concurrency"])
  }

  @Test("MATCH under OR type-checks but always throws at execution")
  func testMatchUnderOrThrows() async throws {
    // SQLite requires MATCH to be consumable by the FTS5 index planner, which OR defeats.
    // The composition compiles — this pins that it can never execute.
    let predicate = articles.match("swift") || title == "Cooking Pasta"
    await #expect(throws: LoomError.self) {
      _ = try await self.titles(where: predicate)
    }
  }

  @Test("Negated MATCH type-checks but always throws at execution")
  func testNegatedMatchThrows() async throws {
    let predicate = !articles.match("swift")
    await #expect(throws: LoomError.self) {
      _ = try await self.titles(where: predicate)
    }
  }

  @Test("MATCH against a non-FTS5 table throws at execution")
  func testMatchOnPlainTableThrows() async throws {
    try await db.exec("CREATE TABLE plain (title TEXT)")
    try await db.exec(raw: "INSERT INTO plain (title) VALUES ('swift')")
    let plain = FTS5Table("plain")
    await #expect(throws: LoomError.self) {
      _ = try await self.db.query(
        "SELECT title FROM plain WHERE \(plain.match("swift"))",
        stepper: { stmt, _ in
          try String.column(of: stmt, at: 0)
        }
      )
    }
  }
}
