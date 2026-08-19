import Foundation
import LoomCore
import Testing

@Suite("Function JsonObject Tests")
@DatabaseActor
struct FunctionJsonObjectTests {
  @Test("Object from labeled columns and literals")
  func testObjectFromValues() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (name TEXT)")
    try await db.exec(raw: "INSERT INTO test (name) VALUES ('Alice')")

    let name = ColumnExpression<String>("name")
    let result = try await db.query("SELECT \(jsonObject(("name", name), ("age", 25))) FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == #"{"name":"Alice","age":25}"#)
  }

  @Test("TEXT value becomes a JSON string; json() nests")
  func testTextIsStringUnlessWrapped() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (tags TEXT)")
    try await db.exec(raw: #"INSERT INTO test (tags) VALUES ('["a"]')"#)

    let tags = ColumnExpression<String>("tags")
    let result = try await db.query(
      "SELECT \(jsonObject(("plain", tags), ("nested", tags.json()))) FROM test"
    ) { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == #"{"plain":"[\"a\"]","nested":["a"]}"#)
  }

  @Test("Empty entry list yields empty object; NULL value becomes JSON null")
  func testEmptyAndNull() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (name TEXT)")
    try await db.exec(raw: "INSERT INTO test (name) VALUES (NULL)")

    let name = ColumnExpression<String>("name")
    let result = try await db.query("SELECT \(jsonObject()), \(jsonObject(("name", name))) FROM test") { stmt, _ in
      (try String.column(of: stmt, at: 0), try String.column(of: stmt, at: 1))
    }

    #expect(result.first?.0 == "{}")
    #expect(result.first?.1 == #"{"name":null}"#)
  }

  @Test("Bool members become JSON booleans")
  func testBoolMembers() async throws {
    let db = try Database.openInMemory()

    let result = try await db.query("SELECT \(jsonObject(("flag", true), ("count", 2)))") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == #"{"flag":true,"count":2}"#)
  }

  @Test("JSONB object stays usable by text-level functions")
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func testJsonbObject() async throws {
    let db = try Database.openInMemory()

    let result = try await db.query("SELECT \(jsonbObject(("a", 1)).json())") { stmt, _ in
      try String?.column(of: stmt, at: 0)
    }

    #expect(result.first == #"{"a":1}"#)

    // The storage class is what distinguishes real JSONB from its text-level equivalent.
    let kinds = try await db.query("SELECT TYPEOF(\(jsonbObject(("a", 1))))") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(kinds.first == "blob")
  }
}
