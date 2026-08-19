import Foundation
import LoomCore
import Testing

@Suite("Function JsonGroupObject Tests")
@DatabaseActor
struct FunctionJsonGroupObjectTests {
  @Test("Grouped rows aggregate into an object")
  func testGroupedRows() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE settings (key TEXT, value TEXT)")
    try await db.exec(raw: "INSERT INTO settings VALUES ('theme', 'dark'), ('lang', 'en')")

    let key = ColumnExpression<String>("key")
    let value = ColumnExpression<String>("value")
    let result = try await db.query("SELECT \(jsonGroupObject(name: key, value: value)) FROM settings") {
      stmt,
      _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == #"{"theme":"dark","lang":"en"}"#)
  }

  @Test("Empty table yields empty object, not NULL")
  func testEmptyTable() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE settings (key TEXT, value TEXT)")

    let key = ColumnExpression<String>("key")
    let value = ColumnExpression<String>("value")
    let result = try await db.query("SELECT \(jsonGroupObject(name: key, value: value)) FROM settings") {
      stmt,
      _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result == ["{}"])
  }

  @Test("NULL values become JSON null members")
  func testNullValues() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE settings (key TEXT, value TEXT)")
    try await db.exec(raw: "INSERT INTO settings VALUES ('theme', NULL)")

    let key = ColumnExpression<String>("key")
    let value = ColumnExpression<String>("value")
    let result = try await db.query("SELECT \(jsonGroupObject(name: key, value: value)) FROM settings") {
      stmt,
      _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == #"{"theme":null}"#)
  }

  @Test("Rows with a NULL name are dropped from the object")
  func testNullNameRowsDropped() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE settings (key TEXT, value INTEGER)")
    try await db.exec(raw: "INSERT INTO settings VALUES ('a', 1), (NULL, 2), ('c', 3)")

    let key = ColumnExpression<String>("key")
    let value = ColumnExpression<Int>("value")
    let result = try await db.query(
      "SELECT \(jsonGroupObject(name: key, value: value)) FROM settings"
    ) { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == #"{"a":1,"c":3}"#)
  }

  @Test("JSONB group object stays usable by text-level functions")
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func testJsonbGroupObject() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE settings (key TEXT, value TEXT)")
    try await db.exec(raw: "INSERT INTO settings VALUES ('theme', 'dark')")

    let key = ColumnExpression<String>("key")
    let value = ColumnExpression<String>("value")
    let result = try await db.query(
      "SELECT \(jsonbGroupObject(name: key, value: value).json()) FROM settings"
    ) { stmt, _ in
      try String?.column(of: stmt, at: 0)
    }

    #expect(result.first == #"{"theme":"dark"}"#)

    // The storage class is what distinguishes real JSONB from its text-level equivalent.
    let kinds = try await db.query(
      "SELECT TYPEOF(\(jsonbGroupObject(name: key, value: value))) FROM settings"
    ) { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(kinds.first == "blob")
  }
}
