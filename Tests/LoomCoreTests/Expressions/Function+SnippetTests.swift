import Foundation
import LoomCore
import Testing

@Suite("Function Snippet Tests")
@DatabaseActor
struct FunctionSnippetTests {
  let db: Database

  init() async throws {
    db = try Database.openInMemory()
    try await db.exec("CREATE VIRTUAL TABLE articles USING fts5(title, body)")
    try await db.exec(
      raw: "INSERT INTO articles (title, body) VALUES ('Database Design', 'A fast sqlite wrapper for swift apps')"
    )
    try await db.exec(raw: "INSERT INTO articles (title, body) VALUES ('Untitled', NULL)")
  }

  let articles = FTS5Table("articles", columns: ["title", "body"])

  func snippets(_ snippet: Snippet, matching query: String) async throws -> [String?] {
    try await db.query(
      "SELECT \(snippet) FROM articles WHERE \(articles.match(query)) ORDER BY rowid",
      stepper: { stmt, _ in
        try String?.column(of: stmt, at: 0)
      }
    )
  }

  @Test("SNIPPET renders the table identifier and five bound arguments")
  func testSQL() {
    var builder = SQLBuilder()
    articles.snippet(column: "body", prefix: "<b>", suffix: "</b>", ellipsis: "…", maxTokens: 8)
      .append(to: &builder)
    let statement = builder.makeStatement()
    #expect(statement.sql == #"SNIPPET( "articles" ,  ? ,  ? ,  ? ,  ? ,  ? )"#)
    #expect(statement.binders.count == 5)
  }

  @Test("Snippet wraps matched tokens and truncates with the ellipsis")
  func testMarkersAndEllipsis() async throws {
    let snippet = articles.snippet(column: "body", prefix: "<b>", suffix: "</b>", ellipsis: "…", maxTokens: 4)
    let result = try await snippets(snippet, matching: "sqlite")
    #expect(result.count == 1)
    let excerpt = try #require(result[0])
    #expect(excerpt.contains("<b>sqlite</b>"))
    #expect(excerpt.contains("…"))
  }

  @Test("Auto-column snippet picks the most relevant column")
  func testAutoColumn() async throws {
    let snippet = articles.snippet(prefix: "<b>", suffix: "</b>", ellipsis: "…", maxTokens: 8)
    let result = try await snippets(snippet, matching: "sqlite")
    #expect(result == ["A fast <b>sqlite</b> wrapper for swift apps"])
  }

  @Test("Snippet of a NULL column value is nil")
  func testNullColumn() async throws {
    let snippet = articles.snippet(column: "body", prefix: "<b>", suffix: "</b>", ellipsis: "…", maxTokens: 8)
    #expect(try await snippets(snippet, matching: "untitled") == [nil])
  }

  @Test("Boundary maxTokens values execute")
  func testMaxTokensBoundaries() async throws {
    let shortest = articles.snippet(column: "body", prefix: "<", suffix: ">", ellipsis: "…", maxTokens: 1)
    #expect(try await snippets(shortest, matching: "sqlite") == ["…<sqlite>…"])

    let longest = articles.snippet(column: "body", prefix: "<", suffix: ">", ellipsis: "…", maxTokens: 64)
    #expect(try await snippets(longest, matching: "sqlite") == ["A fast <sqlite> wrapper for swift apps"])
  }
}
