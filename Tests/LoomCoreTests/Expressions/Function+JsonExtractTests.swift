import Foundation
import LoomCore
import Testing

@Suite("Function JsonExtract Tests")
@DatabaseActor
struct FunctionJsonExtractTests {
  @Test("Extract typed atoms")
  func testExtractTypedAtoms() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(
      raw: #"INSERT INTO test (data) VALUES ('{"name":"Alice","age":25,"score":1.5,"active":true}')"#
    )

    let data = ColumnExpression<String>("data")
    let result = try await db.query(
      """
      SELECT \(data.jsonExtract("$.name", as: String.self)), \
      \(data.jsonExtract("$.age", as: Int.self)), \
      \(data.jsonExtract("$.score", as: Double.self)), \
      \(data.jsonExtract("$.active", as: Bool.self)) FROM test
      """
    ) { stmt, _ in
      (
        try String?.column(of: stmt, at: 0),
        try Int?.column(of: stmt, at: 1),
        try Double?.column(of: stmt, at: 2),
        try Bool?.column(of: stmt, at: 3)
      )
    }

    #expect(result.first?.0 == "Alice")
    #expect(result.first?.1 == 25)
    #expect(result.first?.2 == 1.5)
    #expect(result.first?.3 == true)
  }

  @Test("Object node extracts as JSON text")
  func testExtractObjectAsJSONText() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"address":{"city":"Vienna"}}')"#)

    let data = ColumnExpression<String>("data")
    let result = try await db.query("SELECT \(data.jsonExtract("$.address", as: String.self)) FROM test") {
      stmt,
      _ in
      try String?.column(of: stmt, at: 0)
    }

    #expect(result.first == #"{"city":"Vienna"}"#)
  }

  @Test("Missing path and NULL column extract as nil")
  func testMissingPathAndNull() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"name":"Alice"}')"#)
    try await db.exec(raw: "INSERT INTO test (data) VALUES (NULL)")

    let data = ColumnExpression<String>("data")
    let result = try await db.query("SELECT \(data.jsonExtract("$.missing", as: String.self)) FROM test") {
      stmt,
      _ in
      try String?.column(of: stmt, at: 0)
    }

    #expect(result.count == 2)
    #expect(result[0] == nil)
    #expect(result[1] == nil)
  }

  @Test("Wrong result type throws typeMappingFailed")
  func testWrongTypeThrows() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"age":25}')"#)

    let data = ColumnExpression<String>("data")
    await #expect(throws: LoomError.self) {
      _ = try await db.query("SELECT \(data.jsonExtract("$.age", as: String.self)) FROM test") { stmt, _ in
        try String?.column(of: stmt, at: 0)
      }
    }
  }

  @Test("JSONB extract of scalar decodes identically")
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func testJsonbExtract() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"age":25,"address":{"city":"Vienna"}}')"#)

    let data = ColumnExpression<String>("data")
    let scalars = try await db.query("SELECT \(data.jsonbExtract("$.age", as: Int.self)) FROM test") { stmt, _ in
      try Int?.column(of: stmt, at: 0)
    }

    #expect(scalars.first == 25)

    // An object node extracts as the binary JSONB encoding.
    let blobs = try await db.query("SELECT \(data.jsonbExtract("$.address", as: Data.self)) FROM test") {
      stmt,
      _ in
      try Data?.column(of: stmt, at: 0)
    }

    #expect(blobs.first != nil)
    #expect(blobs.first??.isEmpty == false)

    // The storage class is what distinguishes real JSONB from its text-level equivalent:
    // Data.column accepts TEXT storage, so the emptiness check above cannot.
    let kinds = try await db.query(
      "SELECT TYPEOF(\(data.jsonbExtract("$.address", as: Data.self))) FROM test"
    ) { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(kinds.first == "blob")
  }
}
