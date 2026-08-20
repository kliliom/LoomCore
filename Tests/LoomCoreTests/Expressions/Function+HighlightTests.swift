import Foundation
import LoomCore
import Testing

@Suite("Function Highlight Tests")
@DatabaseActor
struct FunctionHighlightTests {
  let db: Database

  init() async throws {
    db = try Database.openInMemory()
    try await db.exec("CREATE VIRTUAL TABLE articles USING fts5(title, body)")
    try await db.exec(
      raw: "INSERT INTO articles (title, body) VALUES ('Swift Concurrency', 'Actors and tasks in swift explained')"
    )
    try await db.exec(raw: "INSERT INTO articles (title, body) VALUES ('Untitled', NULL)")
  }

  let articles = FTS5Table("articles", columns: ["title", "body"])

  func highlights(_ highlight: Highlight, matching query: String) async throws -> [String?] {
    try await db.query(
      "SELECT \(highlight) FROM articles WHERE \(articles.match(query)) ORDER BY rowid",
      stepper: { stmt, _ in
        try String?.column(of: stmt, at: 0)
      }
    )
  }

  @Test("HIGHLIGHT renders the table identifier and three bound arguments")
  func testSQL() {
    var builder = SQLBuilder()
    articles.highlight(column: "title", prefix: "<b>", suffix: "</b>").append(to: &builder)
    let statement = builder.makeStatement()
    #expect(statement.sql == #"HIGHLIGHT( "articles" ,  ? ,  ? ,  ? )"#)
    #expect(statement.binders.count == 3)
  }

  @Test("Highlight wraps matched tokens in the full column text")
  func testWrapsMatches() async throws {
    let highlight = articles.highlight(column: "title", prefix: "<b>", suffix: "</b>")
    #expect(try await highlights(highlight, matching: "swift") == ["<b>Swift</b> Concurrency"])
  }

  @Test("Columns without a match are returned unmarked")
  func testUnmatchedColumnUnmarked() async throws {
    let highlight = articles.highlight(column: "title", prefix: "<b>", suffix: "</b>")
    #expect(try await highlights(highlight, matching: "actors") == ["Swift Concurrency"])
  }

  @Test("Highlight of a NULL column value is nil")
  func testNullColumn() async throws {
    let highlight = articles.highlight(column: "body", prefix: "<b>", suffix: "</b>")
    #expect(try await highlights(highlight, matching: "untitled") == [nil])
  }
}
