import Foundation
import LoomCore
import Testing

@Suite("Function Json Tests")
@DatabaseActor
struct FunctionJsonTests {
  @Test("json() validates and minifies")
  func testJsonMinifies() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{ "a" : 1 }')"#)

    let data = ColumnExpression<String>("data")
    let result = try await db.query("SELECT \(data.json()) FROM test") { stmt, _ in
      try String?.column(of: stmt, at: 0)
    }

    #expect(result.first == #"{"a":1}"#)
  }

  @Test("json() on malformed input throws")
  func testJsonThrowsOnGarbage() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: "INSERT INTO test (data) VALUES ('not json')")

    let data = ColumnExpression<String>("data")
    await #expect(throws: LoomError.self) {
      _ = try await db.query("SELECT \(data.json()) FROM test") { stmt, _ in
        try String?.column(of: stmt, at: 0)
      }
    }
  }

  @Test("json() of NULL yields nil")
  func testJsonOfNull() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: "INSERT INTO test (data) VALUES (NULL)")

    let data = ColumnExpression<String>("data")
    let result = try await db.query("SELECT \(data.json()) FROM test") { stmt, _ in
      try String?.column(of: stmt, at: 0)
    }

    #expect(result.first == .some(nil))
  }

  @Test("jsonb() round-trips through text-level JSON functions")
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func testJsonbRoundTrip() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT, blob BLOB)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"name":"Alice"}')"#)

    let data = ColumnExpression<String>("data")
    try await db.exec("UPDATE test SET blob = \(data.jsonb())")

    let blob = ColumnExpression<Data>("blob")
    let result = try await db.query(
      "SELECT \(blob.jsonExtract("$.name", as: String.self)), \(blob.json()) FROM test"
    ) { stmt, _ in
      (try String?.column(of: stmt, at: 0), try String?.column(of: stmt, at: 1))
    }

    #expect(result.first?.0 == "Alice")
    #expect(result.first?.1 == #"{"name":"Alice"}"#)

    // The storage class is what distinguishes real JSONB from its text-level equivalent:
    // a JSON_* spelling would store TEXT here and keep every assertion above green.
    let kinds = try await db.query("SELECT TYPEOF(\(blob)) FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(kinds.first == "blob")
  }
}
