import Foundation
import LoomCore
import Testing

@Suite("Expression JsonAccess Tests")
@DatabaseActor
struct ExpressionJsonAccessTests {
  @Test("jsonFragment returns JSON text with quotes preserved")
  func testJsonFragmentKeepsJSONEncoding() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"name":"Alice","tags":["a"]}')"#)

    let data = ColumnExpression<String>("data")
    let result = try await db.query(
      "SELECT \(data.jsonFragment("$.name")), \(data.jsonFragment("$.tags")) FROM test"
    ) { stmt, _ in
      (try String?.column(of: stmt, at: 0), try String?.column(of: stmt, at: 1))
    }

    #expect(result.first?.0 == #""Alice""#)
    #expect(result.first?.1 == #"["a"]"#)
  }

  @Test("jsonValue returns typed plain values")
  func testJsonValueTypedAtoms() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"name":"Alice","age":25}')"#)

    let data = ColumnExpression<String>("data")
    let result = try await db.query(
      "SELECT \(data.jsonValue("$.name", as: String.self)), \(data.jsonValue("$.age", as: Int.self)) FROM test"
    ) { stmt, _ in
      (try String?.column(of: stmt, at: 0), try Int?.column(of: stmt, at: 1))
    }

    #expect(result.first?.0 == "Alice")
    #expect(result.first?.1 == 25)
  }

  @Test("Chained fragment then value")
  func testChaining() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"address":{"city":"Vienna"}}')"#)

    let data = ColumnExpression<String>("data")
    let city = data.jsonFragment("$.address").jsonValue("$.city", as: String.self)
    let result = try await db.query("SELECT \(city) FROM test") { stmt, _ in
      try String?.column(of: stmt, at: 0)
    }

    #expect(result.first == "Vienna")
  }

  @Test("Array index path")
  func testArrayIndexPath() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"tags":["a","b","c"]}')"#)

    let data = ColumnExpression<String>("data")
    let result = try await db.query("SELECT \(data.jsonValue("$.tags[2]", as: String.self)) FROM test") {
      stmt,
      _ in
      try String?.column(of: stmt, at: 0)
    }

    #expect(result.first == "c")
  }

  @Test("NULL document and missing path yield nil")
  func testNullAndMissing() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"name":"Alice"}')"#)
    try await db.exec(raw: "INSERT INTO test (data) VALUES (NULL)")

    let data = ColumnExpression<String>("data")
    let result = try await db.query(
      "SELECT \(data.jsonValue("$.missing", as: String.self)), \(data.jsonFragment("$.missing")) FROM test"
    ) { stmt, _ in
      (try String?.column(of: stmt, at: 0), try String?.column(of: stmt, at: 1))
    }

    #expect(result.count == 2)
    #expect(result[0].0 == nil)
    #expect(result[0].1 == nil)
    #expect(result[1].0 == nil)
    #expect(result[1].1 == nil)
  }

  @Test("JSON null node: -> yields the text 'null', ->> yields SQL NULL")
  func testJSONNullNode() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"name":null}')"#)

    // The one node kind where the two operators disagree: the node exists, so `->`
    // returns its JSON text, while `->>` maps JSON null to SQL NULL.
    let data = ColumnExpression<String>("data")
    let result = try await db.query(
      "SELECT \(data.jsonFragment("$.name")), \(data.jsonValue("$.name", as: String.self)) FROM test"
    ) { stmt, _ in
      (try String?.column(of: stmt, at: 0), try String?.column(of: stmt, at: 1))
    }

    #expect(result.first?.0 == "null")
    #expect(result.first?.1 == .some(nil))
  }

  @Test("Access operators parenthesize themselves against same-precedence neighbors")
  func testParenthesizationAgainstConcatenation() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"name":"Alice"}')"#)

    // `||` shares precedence with `->`/`->>` and associates left: without the emitted
    // parens the SQL reads ('x: ' || "data") ->> '$.name' and fails on malformed JSON.
    let data = ColumnExpression<String>("data")
    let result = try await db.query(
      """
      SELECT 'x: ' || \(data.jsonValue("$.name", as: String.self)), \
      'y: ' || \(data.jsonFragment("$.name")) FROM test
      """
    ) { stmt, _ in
      (try String?.column(of: stmt, at: 0), try String?.column(of: stmt, at: 1))
    }

    #expect(result.first?.0 == "x: Alice")
    #expect(result.first?.1 == #"y: "Alice""#)
  }

  @Test("jsonValue composes with comparison operators")
  func testComparisonComposition() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"age":25}')"#)
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"age":17}')"#)

    let data = ColumnExpression<String>("data")
    let result = try await db.query(
      "SELECT id FROM test WHERE \(data.jsonValue("$.age", as: Int.self) > 21)"
    ) { stmt, _ in
      try Int64.column(of: stmt, at: 0)
    }

    #expect(result == [1])
  }
}
