import Foundation
import Testing

@testable import LoomCore

@Suite("JSONPath Tests")
@DatabaseActor
struct JSONPathTests {
  @Test("Path renders as a literal with no binder")
  func testPathRendersAsLiteral() throws {
    let data = ColumnExpression<String>("data")
    var builder = SQLBuilder()
    data.jsonExtract("$.a", as: Int.self).append(to: &builder)
    let stmt = builder.makeStatement()

    #expect(stmt.sql.contains("'$.a'"))
    #expect(!stmt.sql.contains("?"))
    #expect(stmt.binders.isEmpty)
  }

  @Test("Single quotes in a path are doubled")
  func testQuoteEscaping() throws {
    let path = JSONPath("$.it's")

    #expect(path.renderedSQL == "'$.it''s'")
  }

  @Test("A quote followed by a combining scalar is still doubled")
  func testCombiningScalarQuoteEscaping() throws {
    // Grapheme-level search would see `'` + U+0301 as a single character and skip the
    // quote; escaping must operate on Unicode scalars.
    let path = JSONPath("$.it'\u{301}s")

    #expect(path.renderedSQL == "'$.it''\u{301}s'")
  }

  @Test("Construction preconditions reject empty, NUL-carrying and rootless paths")
  func testValidationPreconditions() async {
    await #expect(processExitsWith: .failure, "empty path must trap") {
      _ = JSONPath("")
    }
    await #expect(processExitsWith: .failure, "NUL byte must trap") {
      _ = JSONPath("$.a\0b")
    }
    await #expect(processExitsWith: .failure, "path without $ root must trap") {
      _ = JSONPath("a.b")
    }
  }

  @Test("String literal initialization")
  func testStringLiteralInit() throws {
    let path: JSONPath = "$.name"

    #expect(path.path == "$.name")
    #expect(path.description == "$.name")
  }

  @Test("Subscript and quoted-key paths execute")
  func testComplexPathsExecute() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"tags":["a","b"],"my key":7}')"#)

    let data = ColumnExpression<String>("data")
    let element = data.jsonExtract("$.tags[1]", as: String.self)
    let quotedKey = data.jsonExtract(#"$."my key""#, as: Int.self)
    let result = try await db.query("SELECT \(element), \(quotedKey) FROM test") { stmt, _ in
      (try String?.column(of: stmt, at: 0), try Int?.column(of: stmt, at: 1))
    }

    #expect(result.first?.0 == "b")
    #expect(result.first?.1 == 7)
  }

  @Test("Path with an embedded quote executes without breaking the literal")
  func testQuotedPathExecutes() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"it''s":1}')"#)

    let data = ColumnExpression<String>("data")
    let expr = data.jsonExtract("$.it's", as: Int.self)
    let result = try await db.query("SELECT \(expr) FROM test") { stmt, _ in
      try Int?.column(of: stmt, at: 0)
    }

    #expect(result.first == 1)
  }

  @Test("A root path in a mutating function affects the whole document")
  func testRootPathWriteMagnitude() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"name":"Alice","age":30}')"#)

    // Pins the trust-warning claim in JSONPath's docs: a path is not scoped to one member —
    // "$" replaces or deletes everything.
    let data = ColumnExpression<String>("data")
    let result = try await db.query(
      "SELECT \(data.jsonSet(.value("$", 1))), \(data.jsonRemove("$")) FROM test"
    ) { stmt, _ in
      (try String?.column(of: stmt, at: 0), try String?.column(of: stmt, at: 1))
    }

    #expect(result.first?.0 == "1")
    #expect(result.first?.1 == .some(nil))
  }

  @Test("Path with a quote followed by a combining scalar executes without breaking the literal")
  func testCombiningScalarPathExecutes() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: "INSERT INTO test (data) VALUES ('{\"it''\u{301}s\":1}')")

    let data = ColumnExpression<String>("data")
    let expr = data.jsonExtract("$.it'\u{301}s", as: Int.self)
    let result = try await db.query("SELECT \(expr) FROM test") { stmt, _ in
      try Int?.column(of: stmt, at: 0)
    }

    #expect(result.first == 1)
  }
}
