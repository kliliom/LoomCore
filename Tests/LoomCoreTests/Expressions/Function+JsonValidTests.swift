import Foundation
import LoomCore
import Testing

@Suite("Function JsonValid Tests")
@DatabaseActor
struct FunctionJsonValidTests {
  @Test("Valid, invalid, and NULL inputs")
  func testJsonValid() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"a":1}')"#)
    try await db.exec(raw: "INSERT INTO test (data) VALUES ('not json')")
    try await db.exec(raw: "INSERT INTO test (data) VALUES (NULL)")

    let data = ColumnExpression<String>("data")
    let result = try await db.query("SELECT \(data.jsonValid()) FROM test ORDER BY id") { stmt, _ in
      try Bool?.column(of: stmt, at: 0)
    }

    #expect(result.count == 3)
    #expect(result[0] == true)
    #expect(result[1] == false)
    #expect(result[2] == nil)
  }

  @Test("Flags form accepts the JSONB this library writes")
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func testFlagsValidateJSONB() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, data)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES (jsonb('{"a":1}'))"#)
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"a":1}')"#)
    try await db.exec(raw: "INSERT INTO test (data) VALUES (NULL)")

    let data = ColumnExpression<Data>("data")
    let result = try await db.query(
      "SELECT \(data.jsonValid()), \(data.jsonValid([.json, .jsonb])) FROM test ORDER BY id"
    ) { stmt, _ in
      (try Bool?.column(of: stmt, at: 0), try Bool?.column(of: stmt, at: 1))
    }

    #expect(result.count == 3)
    #expect(result[0].0 == false)  // the one-argument form rejects JSONB…
    #expect(result[0].1 == true)  // …the flags form accepts it
    #expect(result[1].0 == true)
    #expect(result[1].1 == true)
    #expect(result[2].0 == nil)
    #expect(result[2].1 == nil)
  }

  @Test("Empty flags trap at construction")
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func testEmptyFlagsTrap() async {
    await #expect(processExitsWith: .failure) {
      let data = ColumnExpression<Data>("data")
      _ = data.jsonValid([])
    }
  }

  @Test("Composes with comparison in a predicate")
  func testPredicateComposition() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"a":1}')"#)
    try await db.exec(raw: "INSERT INTO test (data) VALUES ('broken')")

    let data = ColumnExpression<String>("data")
    let result = try await db.query("SELECT id FROM test WHERE \(data.jsonValid() == false)") { stmt, _ in
      try Int64.column(of: stmt, at: 0)
    }

    #expect(result == [2])
  }
}
