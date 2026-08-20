import Foundation
import LoomCore
import Testing

@Suite("Function Bm25 Tests")
@DatabaseActor
struct FunctionBm25Tests {
  let db: Database

  init() async throws {
    db = try Database.openInMemory()
    try await db.exec("CREATE VIRTUAL TABLE articles USING fts5(title, body)")
    try await db.exec(raw: "INSERT INTO articles (title, body) VALUES ('swift', 'other words here')")
    try await db.exec(raw: "INSERT INTO articles (title, body) VALUES ('other', 'a swift phrase here')")
  }

  let articles = FTS5Table("articles", columns: ["title", "body"])

  func titles(orderedBy score: BM25) async throws -> [String] {
    try await db.query(
      "SELECT title FROM articles WHERE \(articles.match("swift")) ORDER BY \(score)",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )
  }

  @Test("BM25 renders the table identifier without weights")
  func testSQLWithoutWeights() {
    var builder = SQLBuilder()
    articles.bm25().append(to: &builder)
    #expect(builder.makeStatement().sql == #"BM25( "articles" )"#)
  }

  @Test("BM25 binds one parameter per weight")
  func testSQLWithWeights() {
    var builder = SQLBuilder()
    articles.bm25(weights: [10, 1]).append(to: &builder)
    let statement = builder.makeStatement()
    #expect(statement.sql == #"BM25( "articles" ,  ? ,  ? )"#)
    #expect(statement.binders.count == 2)
  }

  @Test("Matched rows score negative, best first ascending")
  func testScoresAreNegative() async throws {
    let scores = try await db.query(
      "SELECT \(articles.bm25()) FROM articles WHERE \(articles.match("swift"))",
      stepper: { stmt, _ in
        try Double.column(of: stmt, at: 0)
      }
    )
    #expect(scores.count == 2)
    #expect(scores.allSatisfy { $0 < 0 })
  }

  @Test("Unweighted BM25 ordering agrees with rank")
  func testAgreesWithRank() async throws {
    let byRank = try await db.query(
      "SELECT title FROM articles WHERE \(articles.match("swift")) ORDER BY \(articles.rank)",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )
    #expect(try await titles(orderedBy: articles.bm25()) == byRank)
  }

  @Test("Weights shift relevance between columns")
  func testWeightsChangeOrdering() async throws {
    #expect(try await titles(orderedBy: articles.bm25(weights: [10, 1])) == ["swift", "other"])
    #expect(try await titles(orderedBy: articles.bm25(weights: [1, 10])) == ["other", "swift"])
  }

  func scores(of score: BM25) async throws -> [Double] {
    try await db.query(
      "SELECT \(score) FROM articles WHERE \(articles.match("swift")) ORDER BY rowid",
      stepper: { stmt, _ in
        try Double.column(of: stmt, at: 0)
      }
    )
  }

  @Test("Missing trailing weights default to 1.0")
  func testPartialWeightsPadWithOnes() async throws {
    #expect(try await scores(of: articles.bm25(weights: [10])) == scores(of: articles.bm25(weights: [10, 1])))
    #expect(try await titles(orderedBy: articles.bm25(weights: [10])) == ["swift", "other"])
  }

  @Test("More weights than declared columns traps")
  func testExcessWeightsTrap() async {
    await #expect(processExitsWith: .failure, "excess weight count must trap") {
      _ = FTS5Table("articles", columns: ["title", "body"]).bm25(weights: [10, 1, 99])
    }
  }

  @Test("Without declared columns FTS5 absorbs any weight count silently")
  func testUndeclaredColumnsAbsorbWrongCounts() async throws {
    // The guard cannot fire without a declared column count, and FTS5 raises no error
    // either — it pads missing weights with 1.0 and ignores extras. This is the silent
    // mis-ranking hazard that declaring `columns` exists to catch.
    let undeclared = FTS5Table("articles")
    let weighted = try await scores(of: undeclared.bm25(weights: [10, 1]))
    #expect(try await scores(of: undeclared.bm25(weights: [10])) == weighted)
    #expect(try await scores(of: undeclared.bm25(weights: [10, 1, 99])) == weighted)
  }
}
