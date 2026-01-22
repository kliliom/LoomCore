import Foundation
import Testing

@testable import LoomCore

@Suite("Database Query Tests")
@DatabaseActor
struct DatabaseQueryTests {
  @Test("Query with sql string and binder")
  func testQueryWithSQLAndBinder() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Alice', 25)")
    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Bob', 30)")
    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Charlie', 35)")

    let result = try db.query(
      raw: "SELECT name, age FROM users WHERE age >= ? ORDER BY age ASC",
      binder: { stmt in
        try 30.bind(to: stmt, at: 1)
      },
      stepper: { stmt, _ in
        let name = try String.column(of: stmt, at: 0)
        let age = try Int.column(of: stmt, at: 1)
        return (name, age)
      }
    )

    #expect(result.count == 2)
    #expect(result[0] == ("Bob", 30))
    #expect(result[1] == ("Charlie", 35))

    let stopped = try db.query(
      raw: "SELECT name, age FROM users WHERE age >= ? ORDER BY age ASC",
      binder: { stmt in
        try 30.bind(to: stmt, at: 1)
      },
      stepper: { stmt, stop in
        let name = try String.column(of: stmt, at: 0)
        let age = try Int.column(of: stmt, at: 1)
        stop = true
        return (name, age)
      }
    )

    #expect(stopped.count == 1)
    #expect(stopped[0] == ("Bob", 30))
  }

  @Test("Query with sql string and stepper")
  func testQueryWithSQLStringAndStepper() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Alice', 25)")
    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Bob', 30)")
    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Charlie', 35)")

    let result = try db.query(
      raw: "SELECT name, age FROM users WHERE age >= 30 ORDER BY age ASC",
      stepper: { stmt, _ in
        let name = try String.column(of: stmt, at: 0)
        let age = try Int.column(of: stmt, at: 1)
        return (name, age)
      }
    )

    #expect(result.count == 2)
    #expect(result[0] == ("Bob", 30))
    #expect(result[1] == ("Charlie", 35))

    let stopped = try db.query(
      raw: "SELECT name, age FROM users WHERE age >= 30 ORDER BY age ASC",
      stepper: { stmt, stop in
        let name = try String.column(of: stmt, at: 0)
        let age = try Int.column(of: stmt, at: 1)
        stop = true
        return (name, age)
      }
    )

    #expect(stopped.count == 1)
    #expect(stopped[0] == ("Bob", 30))
  }

  @Test("Query with sql string and managed stepper")
  func testQueryWithSQLStringAndManagedStepper() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Alice', 25)")
    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Bob', 30)")
    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Charlie', 35)")

    let result = try db.query(
      raw: "SELECT name, age FROM users WHERE age >= 30 ORDER BY age ASC",
      stepper: { stmt, index, _ in
        let name = try String.column(of: stmt, at: &index)
        let age = try Int.column(of: stmt, at: &index)
        return (name, age)
      }
    )

    #expect(result.count == 2)
    #expect(result[0] == ("Bob", 30))
    #expect(result[1] == ("Charlie", 35))

    let stopped = try db.query(
      raw: "SELECT name, age FROM users WHERE age >= 30 ORDER BY age ASC",
      stepper: { stmt, index, stop in
        let name = try String.column(of: stmt, at: &index)
        let age = try Int.column(of: stmt, at: &index)
        stop = true
        return (name, age)
      }
    )

    #expect(stopped.count == 1)
    #expect(stopped[0] == ("Bob", 30))
  }

  @Test("Query with sql string and managed binder")
  func testQueryWithSQLAndManagedBinder() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Alice', 25)")
    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Bob', 30)")
    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Charlie', 35)")

    let result = try db.query(
      raw: "SELECT name, age FROM users WHERE age >= ? ORDER BY age ASC",
      binder: { stmt, index in
        try 30.bind(to: stmt, at: &index)
      },
      stepper: { stmt, index, _ in
        let name = try String.column(of: stmt, at: &index)
        let age = try Int.column(of: stmt, at: &index)
        return (name, age)
      }
    )

    #expect(result.count == 2)
    #expect(result[0] == ("Bob", 30))
    #expect(result[1] == ("Charlie", 35))

    let stopped = try db.query(
      raw: "SELECT name, age FROM users WHERE age >= ? ORDER BY age ASC",
      binder: { stmt, index in
        try 30.bind(to: stmt, at: &index)
      },
      stepper: { stmt, index, stop in
        let name = try String.column(of: stmt, at: &index)
        let age = try Int.column(of: stmt, at: &index)
        stop = true
        return (name, age)
      }
    )

    #expect(stopped.count == 1)
    #expect(stopped[0] == ("Bob", 30))
  }

  @Test("Query with sql string and binding")
  func testQueryWithSQLStringAndBinding() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Alice', 25)")
    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Bob', 30)")
    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Charlie', 35)")

    let result = try db.query(
      raw: "SELECT name, age FROM users WHERE age >= ? ORDER BY age ASC",
      binding: 30,
      stepper: { stmt, index, _ in
        let name = try String.column(of: stmt, at: &index)
        let age = try Int.column(of: stmt, at: &index)
        return (name, age)
      }
    )

    #expect(result.count == 2)
    #expect(result[0] == ("Bob", 30))
    #expect(result[1] == ("Charlie", 35))

    let stopped = try db.query(
      raw: "SELECT name, age FROM users WHERE age >= ? ORDER BY age ASC",
      binding: 30,
      stepper: { stmt, index, stop in
        let name = try String.column(of: stmt, at: &index)
        let age = try Int.column(of: stmt, at: &index)
        stop = true
        return (name, age)
      }
    )

    #expect(stopped.count == 1)
    #expect(stopped[0] == ("Bob", 30))
  }

  @Test("Query with SQLStatement and stepper")
  func testQueryWithSQLStatementAndStepper() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Alice', 25)")
    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Bob', 30)")
    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Charlie', 35)")

    let result = try db.query(
      "SELECT name, age FROM users WHERE age >= \(30) ORDER BY age ASC",
      stepper: { stmt, _ in
        let name = try String.column(of: stmt, at: 0)
        let age = try Int.column(of: stmt, at: 1)
        return (name, age)
      }
    )

    #expect(result.count == 2)
    #expect(result[0] == ("Bob", 30))
    #expect(result[1] == ("Charlie", 35))

    let stopped = try db.query(
      "SELECT name, age FROM users WHERE age >= \(30) ORDER BY age ASC",
      stepper: { stmt, stop in
        let name = try String.column(of: stmt, at: 0)
        let age = try Int.column(of: stmt, at: 1)
        stop = true
        return (name, age)
      }
    )

    #expect(stopped.count == 1)
    #expect(stopped[0] == ("Bob", 30))
  }

  @Test("Query with SQLStatement and managed stepper")
  func testQueryWithSQLStatementAndManagedStepper() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Alice', 25)")
    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Bob', 30)")
    try db.exec(raw: "INSERT INTO users (name, age) VALUES ('Charlie', 35)")

    let result = try db.query(
      "SELECT name, age FROM users WHERE age >= \(30) ORDER BY age ASC",
      stepper: { stmt, index, _ in
        let name = try String.column(of: stmt, at: &index)
        let age = try Int.column(of: stmt, at: &index)
        return (name, age)
      }
    )

    #expect(result.count == 2)
    #expect(result[0] == ("Bob", 30))
    #expect(result[1] == ("Charlie", 35))

    let stopped = try db.query(
      "SELECT name, age FROM users WHERE age >= \(30) ORDER BY age ASC",
      stepper: { stmt, index, stop in
        let name = try String.column(of: stmt, at: &index)
        let age = try Int.column(of: stmt, at: &index)
        stop = true
        return (name, age)
      }
    )

    #expect(stopped.count == 1)
    #expect(stopped[0] == ("Bob", 30))
  }
}
