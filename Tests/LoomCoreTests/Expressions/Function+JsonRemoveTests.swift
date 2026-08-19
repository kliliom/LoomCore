import Foundation
import LoomCore
import Testing

@Suite("Function JsonRemove Tests")
@DatabaseActor
struct FunctionJsonRemoveTests {
  @Test("Remove a key and an array element")
  func testRemoveKeyAndElement() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"name":"Alice","tags":["a","b","c"]}')"#)

    let data = ColumnExpression<String>("data")
    try await db.exec("UPDATE test SET data = \(data.jsonRemove("$.name", "$.tags[0]"))")

    let result = try await db.query(
      "SELECT \(data.jsonType("$.name")), \(data.jsonArrayLength("$.tags")), \(data.jsonValue("$.tags[0]", as: String.self)) FROM test"
    ) { stmt, _ in
      (
        try String?.column(of: stmt, at: 0),
        try Int?.column(of: stmt, at: 1),
        try String?.column(of: stmt, at: 2)
      )
    }

    #expect(result.first?.0 == nil)
    #expect(result.first?.1 == 2)
    #expect(result.first?.2 == "b")
  }

  @Test("Missing path is a no-op")
  func testMissingPathNoOp() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"name":"Alice"}')"#)

    let data = ColumnExpression<String>("data")
    let result = try await db.query("SELECT \(data.jsonRemove("$.missing")) FROM test") { stmt, _ in
      try String?.column(of: stmt, at: 0)
    }

    #expect(result.first == #"{"name":"Alice"}"#)
  }

  @Test("NULL document yields NULL result")
  func testNullDocument() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: "INSERT INTO test (data) VALUES (NULL)")

    let data = ColumnExpression<String>("data")
    let result = try await db.query("SELECT \(data.jsonRemove("$.a")) FROM test") { stmt, _ in
      try String?.column(of: stmt, at: 0)
    }

    #expect(result.first == .some(nil))
  }

  @Test("JSONB remove returns the binary encoding")
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func testJsonbRemove() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"a":1,"b":2}')"#)

    let data = ColumnExpression<String>("data")
    let result = try await db.query(
      "SELECT \(data.jsonbRemove("$.a").jsonType("$.b")), \(data.jsonbRemove("$.a").jsonType("$.a")) FROM test"
    ) { stmt, _ in
      (try String?.column(of: stmt, at: 0), try String?.column(of: stmt, at: 1))
    }

    #expect(result.first?.0 == "integer")
    #expect(result.first?.1 == nil)

    // The storage class is what distinguishes real JSONB from its text-level equivalent.
    let kinds = try await db.query("SELECT TYPEOF(\(data.jsonbRemove("$.a"))) FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(kinds.first == "blob")
  }
}
