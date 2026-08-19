import Foundation
import LoomCore
import Testing

@Suite("Function JsonType Tests")
@DatabaseActor
struct FunctionJsonTypeTests {
  @Test("Type names for every JSON type")
  func testTypeNames() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(
      raw: #"INSERT INTO test (data) VALUES ('{"n":null,"t":true,"f":false,"i":1,"r":1.5,"s":"x","a":[],"o":{}}')"#
    )

    let data = ColumnExpression<String>("data")
    let paths: [(JSONPath, String)] = [
      ("$.n", "null"),
      ("$.t", "true"),
      ("$.f", "false"),
      ("$.i", "integer"),
      ("$.r", "real"),
      ("$.s", "text"),
      ("$.a", "array"),
      ("$.o", "object"),
    ]

    for (path, expected) in paths {
      let result = try await db.query("SELECT \(data.jsonType(path)) FROM test") { stmt, _ in
        try String?.column(of: stmt, at: 0)
      }
      #expect(result.first == expected, "type of \(path)")
    }
  }

  @Test("Whole-document type without a path")
  func testWholeDocumentType() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"a":1}')"#)

    let data = ColumnExpression<String>("data")
    let result = try await db.query("SELECT \(data.jsonType()) FROM test") { stmt, _ in
      try String?.column(of: stmt, at: 0)
    }

    #expect(result.first == "object")
  }

  @Test("Missing path and NULL input yield nil")
  func testMissingPathYieldsNil() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (data TEXT)")
    try await db.exec(raw: #"INSERT INTO test (data) VALUES ('{"a":1}')"#)
    try await db.exec(raw: "INSERT INTO test (data) VALUES (NULL)")

    let data = ColumnExpression<String>("data")
    let result = try await db.query("SELECT \(data.jsonType("$.missing")) FROM test") { stmt, _ in
      try String?.column(of: stmt, at: 0)
    }

    #expect(result.count == 2)
    #expect(result[0] == nil)
    #expect(result[1] == nil)
  }
}
