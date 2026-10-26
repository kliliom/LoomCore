import Foundation
import LoomCore
import Testing

@Suite("Function Substring Tests")
@DatabaseActor
struct FunctionSubstringTests {
  @Test("Substring function with length")
  func testSubstringWithLength() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT)")

    try await db.exec(raw: "INSERT INTO users (email) VALUES ('john@example.com')")
    try await db.exec(raw: "INSERT INTO users (email) VALUES ('jane@example.com')")

    let expr = ColumnExpression<String>("email").substring(start: 1, length: 4)

    let result = try await db.query(
      "SELECT \(expr) FROM users ORDER BY id",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 2)
    #expect(result[0] == "john")
    #expect(result[1] == "jane")
  }

  @Test("Substring function without length")
  func testSubstringWithoutLength() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT)")

    try await db.exec(raw: "INSERT INTO users (email) VALUES ('john@example.com')")
    try await db.exec(raw: "INSERT INTO users (email) VALUES ('jane@example.com')")

    let expr = ColumnExpression<String>("email").substring(start: 6)

    let result = try await db.query(
      "SELECT \(expr) FROM users ORDER BY id",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 2)
    #expect(result[0] == "example.com")
    #expect(result[1] == "example.com")
  }

  @Test("Substring function with no rows")
  func testSubstringNoRows() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT)")

    let expr = ColumnExpression<String>("email").substring(start: 1, length: 4)

    let result = try await db.query(
      "SELECT \(expr) FROM users",
      stepper: { stmt, _ in
        try String.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 0)
  }
}
