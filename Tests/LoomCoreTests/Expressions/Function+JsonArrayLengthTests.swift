import Foundation
import LoomCore
import Testing

@Suite("Function JsonArrayLength Tests")
@DatabaseActor
struct FunctionJsonArrayLengthTests {
  @Test("Array length at the root and at a path")
  func testArrayLength() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"tags":["a","b","c"]}')"#)

    let data = ColumnExpression<String>("data")
    let tags = ColumnExpression<String>("data")
    let result = try await db.query(
      "SELECT \(data.jsonArrayLength("$.tags")), \(tags.jsonFragment("$.tags").jsonArrayLength()) FROM test"
    ) { stmt, _ in
      (try Int?.column(of: stmt, at: 0), try Int?.column(of: stmt, at: 1))
    }

    #expect(result.first?.0 == 3)
    #expect(result.first?.1 == 3)
  }

  @Test("Non-array node yields zero")
  func testNonArrayYieldsZero() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"name":"Alice"}')"#)

    let data = ColumnExpression<String>("data")
    let result = try await db.query("SELECT \(data.jsonArrayLength("$.name")) FROM test") { stmt, _ in
      try Int?.column(of: stmt, at: 0)
    }

    #expect(result.first == 0)
  }

  @Test("NULL input and missing path yield nil")
  func testNullYieldsNil() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, data TEXT)")
    try await db.exec(raw: "INSERT INTO test (data) VALUES (NULL)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"a":1}')"#)

    let data = ColumnExpression<String>("data")
    let result = try await db.query("SELECT \(data.jsonArrayLength("$.missing")) FROM test ORDER BY id") {
      stmt,
      _ in
      try Int?.column(of: stmt, at: 0)
    }

    #expect(result.count == 2)
    #expect(result[0] == nil)
    #expect(result[1] == nil)
  }
}
