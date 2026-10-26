import Foundation
import LoomCore
import Testing

@Suite("Function Locate Tests")
@DatabaseActor
struct FunctionLocateTests {
  @Test("Locate function")
  func testLocate() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT)")

    try await db.exec(raw: "INSERT INTO users (email) VALUES ('john@example.com')")
    try await db.exec(raw: "INSERT INTO users (email) VALUES ('jane@test.org')")
    try await db.exec(raw: "INSERT INTO users (email) VALUES ('bob@sample.net')")

    let expr = ColumnExpression<String>("email").locate("@")

    let result = try await db.query(
      "SELECT \(expr) FROM users ORDER BY id",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 3)
    #expect(result[0] == 5)  // "john@example.com" - @ is at position 5
    #expect(result[1] == 5)  // "jane@test.org" - @ is at position 5
    #expect(result[2] == 4)  // "bob@sample.net" - @ is at position 4
  }

  @Test("Locate function not found")
  func testLocateNotFound() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT)")

    try await db.exec(raw: "INSERT INTO users (email) VALUES ('john.example.com')")
    try await db.exec(raw: "INSERT INTO users (email) VALUES ('jane.test.org')")

    let expr = ColumnExpression<String>("email").locate("@")

    let result = try await db.query(
      "SELECT \(expr) FROM users ORDER BY id",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 2)
    #expect(result[0] == 0)  // 0 means not found
    #expect(result[1] == 0)  // 0 means not found
  }

  @Test("Locate function with no rows")
  func testLocateNoRows() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT)")

    let expr = ColumnExpression<String>("email").locate("@")

    let result = try await db.query(
      "SELECT \(expr) FROM users",
      stepper: { stmt, _ in
        try Int?.column(of: stmt, at: 0)
      }
    )

    #expect(result.count == 0)
  }
}
