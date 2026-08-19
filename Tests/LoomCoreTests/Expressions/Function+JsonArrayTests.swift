import Foundation
import LoomCore
import Testing

@Suite("Function JsonArray Tests")
@DatabaseActor
struct FunctionJsonArrayTests {
  @Test("Array from columns and literals")
  func testArrayFromValues() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (name TEXT, age INTEGER)")
    try await db.exec(raw: "INSERT INTO test (name, age) VALUES ('Alice', 25)")

    let name = ColumnExpression<String>("name")
    let age = ColumnExpression<Int>("age")
    let result = try await db.query("SELECT \(jsonArray(name, age, true)) FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == #"["Alice",25,true]"#)
  }

  @Test("TEXT value becomes a JSON string; json() nests")
  func testTextIsStringUnlessWrapped() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (tags TEXT)")
    try await db.exec(raw: #"INSERT INTO test (tags) VALUES ('["a","b"]')"#)

    let tags = ColumnExpression<String>("tags")
    let result = try await db.query(
      "SELECT \(jsonArray(tags)), \(jsonArray(tags.json())) FROM test"
    ) { stmt, _ in
      (try String.column(of: stmt, at: 0), try String.column(of: stmt, at: 1))
    }

    #expect(result.first?.0 == #"["[\"a\",\"b\"]"]"#)
    #expect(result.first?.1 == #"[["a","b"]]"#)
  }

  @Test("Empty argument list yields empty array; NULL becomes JSON null")
  func testEmptyAndNull() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (name TEXT)")
    try await db.exec(raw: "INSERT INTO test (name) VALUES (NULL)")

    let name = ColumnExpression<String>("name")
    let result = try await db.query("SELECT \(jsonArray()), \(jsonArray(name)) FROM test") { stmt, _ in
      (try String.column(of: stmt, at: 0), try String.column(of: stmt, at: 1))
    }

    #expect(result.first?.0 == "[]")
    #expect(result.first?.1 == "[null]")
  }

  @Test("Bool elements become JSON booleans")
  func testBoolElements() async throws {
    let db = try Database.openInMemory()

    let result = try await db.query("SELECT \(jsonArray(1, true, "x"))") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == #"[1,true,"x"]"#)
  }

  @Test("JSONB array stays usable by text-level functions")
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func testJsonbArray() async throws {
    let db = try Database.openInMemory()

    let result = try await db.query("SELECT \(jsonbArray(1, 2).json())") { stmt, _ in
      try String?.column(of: stmt, at: 0)
    }

    #expect(result.first == "[1,2]")

    // The storage class is what distinguishes real JSONB from its text-level equivalent.
    let kinds = try await db.query("SELECT TYPEOF(\(jsonbArray(1, 2)))") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(kinds.first == "blob")
  }
}
