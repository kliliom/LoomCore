import Foundation
import LoomCore
import Testing

@Suite("FTS5Table VerifyColumns Tests")
@DatabaseActor
struct FTS5TableVerifyColumnsTests {
  let db: Database

  init() async throws {
    db = try Database.openInMemory()
    try await db.exec("CREATE VIRTUAL TABLE articles USING fts5(title, body)")
    try await db.exec(
      raw: "INSERT INTO articles (title, body) VALUES ('Swift Concurrency', 'Actors and tasks explained')"
    )
  }

  // MARK: - The drift hazard verifyColumns(on:) exists to catch

  @Test("A reordered declaration silently excerpts the wrong column")
  func testDriftedOrderTargetsWrongColumn() async throws {
    let drifted = FTS5Table("articles", columns: ["body", "title"])
    let result = try await db.query(
      "SELECT \(drifted.highlight(column: "title", prefix: "<", suffix: ">")) FROM articles WHERE \(drifted.match("swift"))",
      stepper: { stmt, _ in
        try String?.column(of: stmt, at: 0)
      }
    )
    // "title" resolves to index 1, which is the real body column — wrong data, no error.
    #expect(result == ["Actors and tasks explained"])
  }

  @Test("An over-declared column fails inconsistently: highlight empty, snippet throws")
  func testOverdeclaredColumnFailureModes() async throws {
    let overdeclared = FTS5Table("articles", columns: ["title", "body", "extra"])

    let highlighted = try await db.query(
      "SELECT \(overdeclared.highlight(column: "extra", prefix: "<", suffix: ">")) FROM articles WHERE \(overdeclared.match("swift"))",
      stepper: { stmt, _ in
        try String?.column(of: stmt, at: 0)
      }
    )
    #expect(highlighted == [""])

    await #expect(throws: LoomError.self) {
      _ = try await db.query(
        "SELECT \(overdeclared.snippet(column: "extra", prefix: "<", suffix: ">", ellipsis: "…", maxTokens: 8)) FROM articles WHERE \(overdeclared.match("swift"))",
        stepper: { stmt, _ in
          try String?.column(of: stmt, at: 0)
        }
      )
    }
  }

  // MARK: - verifyColumns(on:)

  @Test("A declaration matching the live schema verifies")
  func testMatchingDeclarationVerifies() async throws {
    try await FTS5Table("articles", columns: ["title", "body"]).verifyColumns(on: db)
  }

  @Test("A declaration without columns verifies table existence only")
  func testUndeclaredColumnsVerifiesExistence() async throws {
    try await FTS5Table("articles").verifyColumns(on: db)
  }

  @Test("A reordered declaration fails verification")
  func testReorderedDeclarationFails() async throws {
    do {
      try await FTS5Table("articles", columns: ["body", "title"]).verifyColumns(on: db)
      Issue.record("Expected verifyColumns to throw for a reordered declaration")
    } catch let error as LoomError {
      #expect(error.core == .schemaMismatch)
    }
  }

  @Test("An over-declared column list fails verification")
  func testOverdeclaredDeclarationFails() async throws {
    do {
      try await FTS5Table("articles", columns: ["title", "body", "extra"]).verifyColumns(on: db)
      Issue.record("Expected verifyColumns to throw for an over-declared list")
    } catch let error as LoomError {
      #expect(error.core == .schemaMismatch)
    }
  }

  @Test("An under-declared column list fails verification")
  func testUnderdeclaredDeclarationFails() async throws {
    do {
      try await FTS5Table("articles", columns: ["title"]).verifyColumns(on: db)
      Issue.record("Expected verifyColumns to throw for an under-declared list")
    } catch let error as LoomError {
      #expect(error.core == .schemaMismatch)
    }
  }

  @Test("A missing table fails verification")
  func testMissingTableFails() async throws {
    do {
      try await FTS5Table("ghosts", columns: ["title"]).verifyColumns(on: db)
      Issue.record("Expected verifyColumns to throw for a missing table")
    } catch let error as LoomError {
      #expect(error.core == .schemaMismatch)
    }
  }
}
