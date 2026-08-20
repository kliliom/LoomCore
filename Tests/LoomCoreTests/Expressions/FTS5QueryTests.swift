import Foundation
import LoomCore
import Testing

@Suite("FTS5Query Tests")
@DatabaseActor
struct FTS5QueryTests {
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
    try await db.exec(raw: "INSERT INTO articles (title, body) VALUES ('Untitled', NULL)")
  }

  let articles = FTS5Table("articles", columns: ["title", "body"])

  func titles(matching query: FTS5Query) async throws -> [String] {
    try await db.query(
      "SELECT title FROM articles WHERE \(articles.match(query)) ORDER BY rowid",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )
  }

  // MARK: - Rendering

  @Test("Phrase renders double-quoted")
  func testPhrase() {
    #expect(FTS5Query.phrase("swift").queryText == #""swift""#)
  }

  @Test("Multi-word phrase stays a single phrase")
  func testMultiWordPhrase() {
    #expect(FTS5Query.phrase("swift data").queryText == #""swift data""#)
  }

  @Test("Embedded quotes are doubled inside the phrase")
  func testPhraseQuoteDoubling() {
    #expect(FTS5Query.phrase(#"don't "quote""#).queryText == #""don't ""quote""""#)
  }

  @Test("Empty phrase renders as an empty quoted string")
  func testEmptyPhrase() {
    #expect(FTS5Query.phrase("").queryText == #""""#)
  }

  @Test("FTS5 metacharacters are neutralized by quoting")
  func testPhraseNeutralizesMetacharacters() {
    #expect(FTS5Query.phrase("a* ^b : (c)").queryText == #""a* ^b : (c)""#)
  }

  @Test("Phrase fromStart prepends a caret")
  func testPhraseFromStart() {
    #expect(FTS5Query.phrase("swift", fromStart: true).queryText == #"^"swift""#)
  }

  @Test("Prefix appends a star after the closing quote")
  func testPrefix() {
    #expect(FTS5Query.prefix("swi").queryText == #""swi"*"#)
  }

  @Test("Prefix fromStart combines caret and star")
  func testPrefixFromStart() {
    #expect(FTS5Query.prefix("swi", fromStart: true).queryText == #"^"swi"*"#)
  }

  @Test("NEAR renders quoted phrases and the distance")
  func testNear() {
    #expect(FTS5Query.near(["one", "two"], distance: 5).queryText == #"NEAR("one" "two", 5)"#)
  }

  @Test("NEAR defaults to FTS5's distance of 10")
  func testNearDefaultDistance() {
    #expect(FTS5Query.near(["one", "two"]).queryText == #"NEAR("one" "two", 10)"#)
  }

  @Test("Column filter renders a quoted identifier and parenthesized query")
  func testColumnFilter() {
    #expect(FTS5Query.column("title", .phrase("swift")).queryText == #""title" : ("swift")"#)
  }

  @Test("Multi-column filter renders a braced identifier set")
  func testColumnsFilter() {
    #expect(FTS5Query.columns(["title", "body"], .phrase("swift")).queryText == #"{"title" "body"} : ("swift")"#)
  }

  @Test("Combinators parenthesize with explicit operators")
  func testCombinators() {
    #expect(FTS5Query.phrase("a").and(.phrase("b")).queryText == #"("a" AND "b")"#)
    #expect(FTS5Query.phrase("a").or(.phrase("b")).queryText == #"("a" OR "b")"#)
    #expect(FTS5Query.phrase("a").not(.phrase("b")).queryText == #"("a" NOT "b")"#)
  }

  @Test("Nested combinators keep explicit precedence")
  func testNestedCombinators() {
    let query = FTS5Query.phrase("a").and(.phrase("b")).or(.phrase("c"))
    #expect(query.queryText == #"(("a" AND "b") OR "c")"#)
  }

  @Test("Description mirrors the rendered query text")
  func testDescription() {
    let query = FTS5Query.prefix("swi")
    #expect(query.description == query.queryText)
  }

  @Test("Equatable and Hashable follow the rendered query")
  func testHashable() {
    #expect(FTS5Query.phrase("a") == FTS5Query.phrase("a"))
    #expect(FTS5Query.phrase("a") != FTS5Query.prefix("a"))
  }

  // MARK: - Execution

  @Test("Prefix matches tokens by prefix")
  func testPrefixExecution() async throws {
    #expect(try await titles(matching: .prefix("swi")) == ["Swift Concurrency", "Database Design"])
  }

  @Test("Phrase requires adjacency, unlike separate tokens")
  func testPhraseAdjacencyExecution() async throws {
    #expect(try await titles(matching: .phrase("fast sqlite")) == ["Database Design"])
    #expect(try await titles(matching: .phrase("sqlite fast")) == [])
  }

  @Test("NOT excludes rows matching the right-hand side")
  func testNotExecution() async throws {
    #expect(try await titles(matching: .prefix("swift").not(.phrase("database"))) == ["Swift Concurrency"])
  }

  @Test("OR matches rows satisfying either side")
  func testOrExecution() async throws {
    #expect(
      try await titles(matching: .phrase("pasta").or(.phrase("concurrency"))) == ["Swift Concurrency", "Cooking Pasta"]
    )
  }

  @Test("Column filter restricts the match to one column")
  func testColumnFilterExecution() async throws {
    #expect(try await titles(matching: .column("title", .phrase("swift"))) == ["Swift Concurrency"])
    #expect(try await titles(matching: .column("body", .phrase("swift"))) == ["Swift Concurrency", "Database Design"])
  }

  @Test("Multi-column filter searches only the listed columns")
  func testColumnsFilterExecution() async throws {
    #expect(try await titles(matching: .columns(["title", "body"], .phrase("salt"))) == ["Cooking Pasta"])
  }

  @Test("NEAR respects the token distance")
  func testNearExecution() async throws {
    // "Boil water and add salt": three tokens separate "boil" and "salt".
    #expect(try await titles(matching: .near(["boil", "salt"], distance: 3)) == ["Cooking Pasta"])
    #expect(try await titles(matching: .near(["boil", "salt"], distance: 2)) == [])
  }

  @Test("Empty phrase matches no rows without throwing")
  func testEmptyPhraseExecution() async throws {
    #expect(try await titles(matching: .phrase("")) == [])
  }
}
