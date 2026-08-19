import Foundation
import LoomCore
import Testing

@Suite("Function JsonGroupArray Tests")
@DatabaseActor
struct FunctionJsonGroupArrayTests {
  @Test("Grouped rows aggregate into arrays")
  func testGroupedRows() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE books (author TEXT, title TEXT)")
    try await db.exec(raw: "INSERT INTO books VALUES ('ann', 'A'), ('ann', 'B'), ('bob', 'C')")

    let title = ColumnExpression<String>("title")
    let result = try await db.query(
      "SELECT \(title.jsonGroupArray()) FROM books GROUP BY author ORDER BY author"
    ) { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result == [#"["A","B"]"#, #"["C"]"#])
  }

  @Test("Empty table yields empty array, not NULL")
  func testEmptyTable() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE books (title TEXT)")

    let title = ColumnExpression<String>("title")
    let result = try await db.query("SELECT \(title.jsonGroupArray()) FROM books") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result == ["[]"])
  }

  @Test("NULL input values become JSON null elements")
  func testNullElements() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE books (title TEXT)")
    try await db.exec(raw: "INSERT INTO books VALUES ('A'), (NULL)")

    let title = ColumnExpression<String>("title")
    let result = try await db.query("SELECT \(title.jsonGroupArray()) FROM books") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result == [#"["A",null]"#])
  }

  @Test("JSONB group array stays usable by text-level functions")
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func testJsonbGroupArray() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE books (title TEXT)")
    try await db.exec(raw: "INSERT INTO books VALUES ('A')")

    let title = ColumnExpression<String>("title")
    let result = try await db.query("SELECT \(title.jsonbGroupArray().json()) FROM books") { stmt, _ in
      try String?.column(of: stmt, at: 0)
    }

    #expect(result.first == #"["A"]"#)

    // The storage class is what distinguishes real JSONB from its text-level equivalent.
    let kinds = try await db.query("SELECT TYPEOF(\(title.jsonbGroupArray())) FROM books") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(kinds.first == "blob")
  }
}
