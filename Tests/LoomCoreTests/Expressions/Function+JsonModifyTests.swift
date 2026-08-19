import Foundation
import LoomCore
import Testing

@Suite("Function JsonModify Tests")
@DatabaseActor
struct FunctionJsonModifyTests {
  struct Address: Codable, JSONBindable, Equatable {
    let city: String
  }

  @Test("jsonSet overwrites and creates")
  func testJsonSet() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"name":"Alice","age":25}')"#)

    let data = ColumnExpression<String>("data")
    try await db.exec("UPDATE test SET data = \(data.jsonSet(.value("$.age", 26), .value("$.verified", true)))")

    let result = try await db.query(
      "SELECT \(data.jsonValue("$.age", as: Int.self)), \(data.jsonValue("$.verified", as: Bool.self)) FROM test"
    ) { stmt, _ in
      (try Int?.column(of: stmt, at: 0), try Bool?.column(of: stmt, at: 1))
    }

    #expect(result.first?.0 == 26)
    #expect(result.first?.1 == true)
  }

  @Test("jsonInsert only creates")
  func testJsonInsert() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"age":25}')"#)

    let data = ColumnExpression<String>("data")
    try await db.exec("UPDATE test SET data = \(data.jsonInsert(.value("$.age", 99), .value("$.theme", "light")))")

    let result = try await db.query(
      "SELECT \(data.jsonValue("$.age", as: Int.self)), \(data.jsonValue("$.theme", as: String.self)) FROM test"
    ) { stmt, _ in
      (try Int?.column(of: stmt, at: 0), try String?.column(of: stmt, at: 1))
    }

    #expect(result.first?.0 == 25)  // untouched
    #expect(result.first?.1 == "light")  // created
  }

  @Test("jsonReplace only overwrites")
  func testJsonReplace() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"age":25}')"#)

    let data = ColumnExpression<String>("data")
    try await db.exec("UPDATE test SET data = \(data.jsonReplace(.value("$.age", 26), .value("$.theme", "light")))")

    let result = try await db.query(
      "SELECT \(data.jsonValue("$.age", as: Int.self)), \(data.jsonValue("$.theme", as: String.self)) FROM test"
    ) { stmt, _ in
      (try Int?.column(of: stmt, at: 0), try String?.column(of: stmt, at: 1))
    }

    #expect(result.first?.0 == 26)  // overwritten
    #expect(result.first?.1 == nil)  // not created
  }

  @Test("Assignment .value stores JSON string, .json nests a document")
  func testValueVersusJsonAssignment() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: "INSERT INTO test (data) VALUES ('{}')")

    let data = ColumnExpression<String>("data")
    let address = Address(city: "Vienna")
    try await db.exec(
      "UPDATE test SET data = \(data.jsonSet(.value("$.asString", address), .json("$.asObject", address)))"
    )

    let result = try await db.query(
      """
      SELECT \(data.jsonType("$.asString")), \(data.jsonType("$.asObject")), \
      \(data.jsonExtract("$.asObject.city", as: String.self)) FROM test
      """
    ) { stmt, _ in
      (
        try String?.column(of: stmt, at: 0),
        try String?.column(of: stmt, at: 1),
        try String?.column(of: stmt, at: 2)
      )
    }

    #expect(result.first?.0 == "text")  // bound TEXT stays a JSON string
    #expect(result.first?.1 == "object")  // JSON(?)-wrapped text nests
    #expect(result.first?.2 == "Vienna")
  }

  @Test("Bool assignments store JSON booleans, not integers")
  func testBoolAssignmentStoresJSONBoolean() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: "INSERT INTO test (data) VALUES ('{}')")

    let data = ColumnExpression<String>("data")
    try await db.exec(
      "UPDATE test SET data = \(data.jsonSet(.value("$.yes", true), .value("$.no", false), .json("$.viaJson", true)))"
    )

    let result = try await db.query(
      "SELECT \(data.jsonType("$.yes")), \(data.jsonType("$.no")), \(data.jsonType("$.viaJson")) FROM test"
    ) { stmt, _ in
      (
        try String?.column(of: stmt, at: 0),
        try String?.column(of: stmt, at: 1),
        try String?.column(of: stmt, at: 2)
      )
    }

    #expect(result.first?.0 == "true")
    #expect(result.first?.1 == "false")
    #expect(result.first?.2 == "true")
  }

  @Test("Bool written through jsonSet reads back through JSONBindable")
  func testBoolRoundTripThroughJSONBindable() async throws {
    struct Flags: Codable, JSONBindable, Equatable {
      let verified: Bool
    }

    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: "INSERT INTO test (data) VALUES ('{}')")

    let data = ColumnExpression<String>("data")
    try await db.exec("UPDATE test SET data = \(data.jsonSet(.value("$.verified", true)))")

    let result = try await db.query("SELECT \(data) FROM test") { stmt, _ in
      try Flags.column(of: stmt, at: 0)
    }

    #expect(result.first == Flags(verified: true))
  }

  @Test("Assigning a nil optional stores JSON null")
  func testNilAssignmentStoresJSONNull() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"name":"Alice"}')"#)

    let data = ColumnExpression<String>("data")
    let nothing: String? = nil
    try await db.exec("UPDATE test SET data = \(data.jsonSet(.value("$.name", nothing)))")

    let result = try await db.query("SELECT \(data.jsonType("$.name")) FROM test") { stmt, _ in
      try String?.column(of: stmt, at: 0)
    }

    #expect(result.first == "null")
  }

  @Test("NULL document yields NULL result")
  func testNullDocument() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: "INSERT INTO test (data) VALUES (NULL)")

    let data = ColumnExpression<String>("data")
    let result = try await db.query("SELECT \(data.jsonSet(.value("$.a", 1))) FROM test") { stmt, _ in
      try String?.column(of: stmt, at: 0)
    }

    #expect(result.first == .some(nil))
  }

  @Test("Malformed document throws")
  func testMalformedDocumentThrows() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: "INSERT INTO test (data) VALUES ('not json')")

    let data = ColumnExpression<String>("data")
    await #expect(throws: LoomError.self) {
      _ = try await db.query("SELECT \(data.jsonSet(.value("$.a", 1))) FROM test") { stmt, _ in
        try String?.column(of: stmt, at: 0)
      }
    }
  }

  @Test("JSONB set/insert/replace return the binary encoding")
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func testJsonbModify() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"age":25}')"#)

    let data = ColumnExpression<String>("data")
    let blobs = try await db.query("SELECT \(data.jsonbSet(.value("$.age", 26))) FROM test") { stmt, _ in
      try Data?.column(of: stmt, at: 0)
    }

    #expect(blobs.first??.isEmpty == false)

    // The storage class is what distinguishes real JSONB from its text-level equivalent:
    // Data.column accepts TEXT storage, so the emptiness check above cannot.
    let kinds = try await db.query(
      "SELECT TYPEOF(\(data.jsonbSet(.value("$.age", 26)))), TYPEOF(\(data.jsonbInsert(.value("$.theme", "light")))) FROM test"
    ) { stmt, _ in
      (try String.column(of: stmt, at: 0), try String.column(of: stmt, at: 1))
    }

    #expect(kinds.first?.0 == "blob")
    #expect(kinds.first?.1 == "blob")

    // The binary result stays fully usable by the text-level JSON functions.
    let roundTrip = try await db.query(
      "SELECT \(data.jsonbInsert(.value("$.theme", "light")).jsonValue("$.theme", as: String.self)) FROM test"
    ) { stmt, _ in
      try String?.column(of: stmt, at: 0)
    }

    #expect(roundTrip.first == "light")

    // JSONB_REPLACE keeps replace-only semantics: overwrites $.age, skips missing $.theme.
    let replaced = try await db.query(
      """
      SELECT \(data.jsonbReplace(.value("$.age", 30)).jsonValue("$.age", as: Int.self)), \
      \(data.jsonbReplace(.value("$.theme", "dark")).jsonType("$.theme")), \
      TYPEOF(\(data.jsonbReplace(.value("$.age", 30)))) FROM test
      """
    ) { stmt, _ in
      (
        try Int?.column(of: stmt, at: 0),
        try String?.column(of: stmt, at: 1),
        try String.column(of: stmt, at: 2)
      )
    }

    #expect(replaced.first?.0 == 30)  // overwritten
    #expect(replaced.first?.1 == nil)  // not created
    #expect(replaced.first?.2 == "blob")
  }
}
