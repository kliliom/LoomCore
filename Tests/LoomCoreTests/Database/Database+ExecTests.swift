import Foundation
import LoomCore
import Testing

@Suite("Database Exec Tests")
@DatabaseActor
struct DatabaseExecTests {

  @Test("Exec with sql string and binder")
  func testExecWithSQLAndBinder() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    try await db.exec(
      raw: "INSERT INTO users (name, age) VALUES (?, ?)",
      binder: { stmt in
        try "Alice".bind(to: stmt, at: 1)
        try 25.bind(to: stmt, at: 2)
      }
    )

    let result = try await db.query("SELECT name, age FROM users") { stmt, _ in
      let name = try String.column(of: stmt, at: 0)
      let age = try Int.column(of: stmt, at: 1)
      return (name, age)
    }

    #expect(result.count == 1)
    #expect(result.first?.0 == "Alice")
    #expect(result.first?.1 == 25)
  }

  @Test("Exec with sql string")
  func testExecWithSQLString() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    try await db.exec(raw: "INSERT INTO users (name, age) VALUES ('Alice', 25)")

    let result = try await db.query("SELECT name, age FROM users") { stmt, _ in
      let name = try String.column(of: stmt, at: 0)
      let age = try Int.column(of: stmt, at: 1)
      return (name, age)
    }

    #expect(result.count == 1)
    #expect(result.first?.0 == "Alice")
    #expect(result.first?.1 == 25)
  }

  @Test("Exec with sql string and managed binder")
  func testExecWithSQLAndManagedBinder() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    try await db.exec(
      raw: "INSERT INTO users (name, age) VALUES (?, ?)",
      binder: { stmt, index in
        try "Alice".bind(to: stmt, at: &index)
        try 25.bind(to: stmt, at: &index)
      }
    )

    let result = try await db.query("SELECT name, age FROM users") { stmt, _ in
      let name = try String.column(of: stmt, at: 0)
      let age = try Int.column(of: stmt, at: 1)
      return (name, age)
    }

    #expect(result.count == 1)
    #expect(result.first?.0 == "Alice")
    #expect(result.first?.1 == 25)
  }

  @Test("Exec with sql string and binding")
  func testExecWithSQLAndBinding() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    try await db.exec(
      raw: "INSERT INTO users (name, age) VALUES (?, ?)",
      binding: "Alice",
      25
    )

    let result = try await db.query("SELECT name, age FROM users") { stmt, _ in
      let name = try String.column(of: stmt, at: 0)
      let age = try Int.column(of: stmt, at: 1)
      return (name, age)
    }

    #expect(result.count == 1)
    #expect(result.first?.0 == "Alice")
    #expect(result.first?.1 == 25)
  }

  @Test("Exec with SQLStatement")
  func testExecWithSQLStatement() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    try await db.exec("INSERT INTO users (name, age) VALUES (\("Alice"), \(25))")

    let result = try await db.query("SELECT name, age FROM users") { stmt, _ in
      let name = try String.column(of: stmt, at: 0)
      let age = try Int.column(of: stmt, at: 1)
      return (name, age)
    }

    #expect(result.count == 1)
    #expect(result.first?.0 == "Alice")
    #expect(result.first?.1 == 25)
  }
}
