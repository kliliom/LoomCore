import Foundation
import LoomCore
import Testing

@Suite("Function JsonPatch Tests")
@DatabaseActor
struct FunctionJsonPatchTests {
  struct ProfilePatch: Codable, JSONBindable {
    let displayName: String
  }

  @Test("Patch merges and null removes keys")
  func testMergeAndNullRemoval() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"name":"Alice","legacy":1}')"#)

    let data = ColumnExpression<String>("data")
    try await db.exec("UPDATE test SET data = \(data.jsonPatch(#"{"name":"Bob","legacy":null,"new":true}"#))")

    let result = try await db.query(
      """
      SELECT \(data.jsonValue("$.name", as: String.self)), \(data.jsonType("$.legacy")), \
      \(data.jsonValue("$.new", as: Bool.self)) FROM test
      """
    ) { stmt, _ in
      (
        try String?.column(of: stmt, at: 0),
        try String?.column(of: stmt, at: 1),
        try Bool?.column(of: stmt, at: 2)
      )
    }

    #expect(result.first?.0 == "Bob")
    #expect(result.first?.1 == nil)  // removed by null
    #expect(result.first?.2 == true)  // added
  }

  @Test("JSONBindable patch merges as a document without wrapping")
  func testJSONBindablePatch() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"displayName":"Alice","age":25}')"#)

    let data = ColumnExpression<String>("data")
    try await db.exec("UPDATE test SET data = \(data.jsonPatch(ProfilePatch(displayName: "Bob")))")

    let result = try await db.query(
      "SELECT \(data.jsonValue("$.displayName", as: String.self)), \(data.jsonValue("$.age", as: Int.self)) FROM test"
    ) { stmt, _ in
      (try String?.column(of: stmt, at: 0), try Int?.column(of: stmt, at: 1))
    }

    #expect(result.first?.0 == "Bob")  // merged
    #expect(result.first?.1 == 25)  // untouched
  }

  @Test("NULL document yields NULL result")
  func testNullDocument() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: "INSERT INTO test (data) VALUES (NULL)")

    let data = ColumnExpression<String>("data")
    let result = try await db.query("SELECT \(data.jsonPatch(#"{"a":1}"#)) FROM test") { stmt, _ in
      try String?.column(of: stmt, at: 0)
    }

    #expect(result.first == .some(nil))
  }

  @Test("JSONB patch returns the binary encoding")
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func testJsonbPatch() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"a":1}')"#)

    let data = ColumnExpression<String>("data")
    let result = try await db.query(
      "SELECT \(data.jsonbPatch(#"{"b":2}"#).jsonValue("$.b", as: Int.self)) FROM test"
    ) { stmt, _ in
      try Int?.column(of: stmt, at: 0)
    }

    #expect(result.first == 2)

    // The storage class is what distinguishes real JSONB from its text-level equivalent.
    let kinds = try await db.query("SELECT TYPEOF(\(data.jsonbPatch(#"{"b":2}"#))) FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(kinds.first == "blob")
  }
}
