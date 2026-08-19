import Foundation
import LoomCore
import Testing

@Suite("Function JsonErrorPosition Tests")
@DatabaseActor
struct FunctionJsonErrorPositionTests {
  @Test("Valid, malformed, and NULL inputs")
  func testJsonErrorPosition() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"a":1}')"#)
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"a" 1}')"#)
    try await db.exec(raw: "INSERT INTO test (data) VALUES (NULL)")

    let data = ColumnExpression<String>("data")
    let result = try await db.query("SELECT \(data.jsonErrorPosition()) FROM test ORDER BY id") { stmt, _ in
      try Int?.column(of: stmt, at: 0)
    }

    #expect(result == [0, 6, nil])
  }

  @Test("Composes with jsonValid in a cleanup predicate")
  func testCleanupComposition() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"a":1}')"#)
    try await db.exec(raw: "INSERT INTO test (data) VALUES ('broken')")

    let data = ColumnExpression<String>("data")
    let result = try await db.query(
      "SELECT id, \(data.jsonErrorPosition()) FROM test WHERE \(data.jsonValid() == false)"
    ) { stmt, _ in
      (try Int64.column(of: stmt, at: 0), try Int?.column(of: stmt, at: 1))
    }

    #expect(result.count == 1)
    #expect(result.first?.0 == 2)
    #expect(result.first?.1 == 1)
  }
}
