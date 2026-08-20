import Foundation
import LoomCore
import Testing

@Suite("FTS5Table Tests")
@DatabaseActor
struct FTS5TableTests {
  let db: Database

  init() async throws {
    db = try Database.openInMemory()
    try await db.exec("CREATE VIRTUAL TABLE notes USING fts5(text)")
    try await db.exec(raw: "INSERT INTO notes (text) VALUES ('swift swift swift')")
    try await db.exec(raw: "INSERT INTO notes (text) VALUES ('swift')")
    try await db.exec(raw: "INSERT INTO notes (text) VALUES ('nothing here')")
  }

  let notes = FTS5Table("notes", columns: ["text"])

  @Test("Table name and columns are exposed as supplied")
  func testProperties() {
    let table = FTS5Table("articles", columns: ["title", "body"])
    #expect(table.tableName == "articles")
    #expect(table.columns == ["title", "body"])
  }

  @Test("Columns default to empty")
  func testDefaultColumns() {
    #expect(FTS5Table("articles").columns.isEmpty)
  }

  @Test("Table identifier renders double-quoted with embedded quotes doubled")
  func testQuotedRendering() {
    var builder = SQLBuilder()
    FTS5Table(#"we"ird"#).match("x").append(to: &builder)
    #expect(builder.makeStatement().sql == #"( "we""ird" MATCH ? )"#)
  }

  @Test("Rank column renders table-qualified")
  func testRankRendering() {
    var builder = SQLBuilder()
    notes.rank.append(to: &builder)
    #expect(builder.makeStatement().sql == #""notes"."rank""#)
  }

  @Test("Equatable and Hashable follow table name and columns")
  func testHashable() {
    #expect(FTS5Table("a", columns: ["x"]) == FTS5Table("a", columns: ["x"]))
    #expect(FTS5Table("a", columns: ["x"]) != FTS5Table("a", columns: ["y"]))
    #expect(FTS5Table("a") != FTS5Table("b"))
  }

  @Test("ORDER BY rank returns the best match first")
  func testRankOrdersBestFirst() async throws {
    let result = try await db.query(
      "SELECT text FROM notes WHERE \(notes.match("swift")) ORDER BY \(notes.rank)",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )
    #expect(result == ["swift swift swift", "swift"])
  }

  @Test("Rank is NULL outside a full-text query")
  func testRankWithoutMatchIsNull() async throws {
    let result = try await db.query(
      "SELECT \(notes.rank) FROM notes",
      stepper: { stmt, _ in
        try Double?.column(of: stmt, at: 0)
      }
    )
    #expect(result == [nil, nil, nil])
  }
}
