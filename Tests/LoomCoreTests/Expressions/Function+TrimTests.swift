import Foundation
import LoomCore
import Testing

@Suite("Function Trim Tests")
@DatabaseActor
struct FunctionTrimTests {
  @Test("Trim function")
  func testTrim() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")

    try await db.exec(raw: "INSERT INTO users (name) VALUES ('  John  ')")
    try await db.exec(raw: "INSERT INTO users (name) VALUES (' Jane ')")
    try await db.exec(raw: "INSERT INTO users (name) VALUES ('Bob')")

    let expr = ColumnExpression<String>("name").trim()

    let result = try await db.query(
      "SELECT \(expr) FROM users ORDER BY id",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 3)
    #expect(result[0] == "John")
    #expect(result[1] == "Jane")
    #expect(result[2] == "Bob")
  }

  @Test("Trim function with no rows")
  func testTrimNoRows() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")

    let expr = ColumnExpression<String>("name").trim()

    let result = try await db.query(
      "SELECT \(expr) FROM users",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 0)
  }
}
