import Foundation
import LoomCore
import Testing

@Suite("Function JsonEach Tests")
@DatabaseActor
struct FunctionJsonEachTests {
  @Test("Iterate a JSON array")
  func testIterateArray() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (data TEXT)")
    try await db.exec(raw: #"INSERT INTO users (data) VALUES ('{"tags":["a","b","c"]}')"#)

    let data = ColumnExpression<String>("data", of: "users")
    let tag = JSONEach(data, "$.tags")
    let result = try await db.query(
      "SELECT \(tag.value(as: String.self)) FROM users, \(tag) ORDER BY \(tag.id)"
    ) { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result == ["a", "b", "c"])
  }

  @Test("Iterate an object with string keys")
  func testIterateObject() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE docs (data TEXT)")
    try await db.exec(raw: #"INSERT INTO docs (data) VALUES ('{"a":1,"b":2}')"#)

    let data = ColumnExpression<String>("data", of: "docs")
    let member = JSONEach(data)
    let result = try await db.query(
      "SELECT \(member.key(as: String.self)), \(member.value(as: Int.self)) FROM docs, \(member) ORDER BY \(member.key(as: String.self))"
    ) { stmt, _ in
      (try String.column(of: stmt, at: 0), try Int.column(of: stmt, at: 1))
    }

    #expect(result.count == 2)
    #expect(result[0] == ("a", 1))
    #expect(result[1] == ("b", 2))
  }

  @Test("Array keys are integer indexes")
  func testArrayKeysAreInts() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE docs (data TEXT)")
    try await db.exec(raw: #"INSERT INTO docs (data) VALUES ('["x","y"]')"#)

    let data = ColumnExpression<String>("data", of: "docs")
    let element = JSONEach(data)
    let result = try await db.query(
      "SELECT \(element.key(as: Int.self)), \(element.type), \(element.fullkey), \(element.path) FROM docs, \(element)"
    ) { stmt, _ in
      (
        try Int.column(of: stmt, at: 0),
        try String.column(of: stmt, at: 1),
        try String.column(of: stmt, at: 2),
        try String.column(of: stmt, at: 3)
      )
    }

    #expect(result.count == 2)
    #expect(result[0] == (0, "text", "$[0]", "$"))
    #expect(result[1] == (1, "text", "$[1]", "$"))
  }

  @Test("Alias allows two instances in one query")
  func testAliasedInstances() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE docs (data TEXT)")
    try await db.exec(raw: #"INSERT INTO docs (data) VALUES ('{"a":[1,2],"b":[3]}')"#)

    let data = ColumnExpression<String>("data", of: "docs")
    let left = JSONEach(data, "$.a", alias: "left_each")
    let right = JSONEach(data, "$.b", alias: "right_each")
    let result = try await db.query(
      "SELECT \(left.value(as: Int.self)), \(right.value(as: Int.self)) FROM docs, \(left), \(right) ORDER BY \(left.id)"
    ) { stmt, _ in
      (try Int.column(of: stmt, at: 0), try Int.column(of: stmt, at: 1))
    }

    #expect(result.count == 2)
    #expect(result[0] == (1, 3))
    #expect(result[1] == (2, 3))
  }

  @Test("Filter rows whose JSON array contains a value")
  func testContainmentFilter() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, data TEXT)")
    try await db.exec(raw: #"INSERT INTO users (data) VALUES ('{"tags":["swift","sql"]}')"#)
    try await db.exec(raw: #"INSERT INTO users (data) VALUES ('{"tags":["rust"]}')"#)

    // "id" must be qualified: json_each exposes its own "id" column.
    let userID = ColumnExpression<Int64>("id", of: "users")
    let data = ColumnExpression<String>("data", of: "users")
    let tag = JSONEach(data, "$.tags")
    let result = try await db.query(
      "SELECT \(userID) FROM users, \(tag) WHERE \(tag.value(as: String.self) == "swift")"
    ) { stmt, _ in
      try Int64.column(of: stmt, at: 0)
    }

    #expect(result == [1])
  }

  @Test("atom is NULL for containers")
  func testAtomNullForContainers() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE docs (data TEXT)")
    try await db.exec(raw: #"INSERT INTO docs (data) VALUES ('{"nested":{"a":1}}')"#)

    let data = ColumnExpression<String>("data", of: "docs")
    let member = JSONEach(data)
    let result = try await db.query(
      "SELECT \(member.atom(as: String.self)), \(member.type) FROM docs, \(member)"
    ) { stmt, _ in
      (try String?.column(of: stmt, at: 0), try String.column(of: stmt, at: 1))
    }

    #expect(result.count == 1)
    #expect(result[0].0 == nil)
    #expect(result[0].1 == "object")
  }

  @Test("Empty container, scalar root, and NULL source row counts")
  func testRowCountEdgeCases() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE docs (id INTEGER PRIMARY KEY, data TEXT)")
    try await db.exec(raw: "INSERT INTO docs (data) VALUES ('[]')")
    try await db.exec(raw: "INSERT INTO docs (data) VALUES ('7')")
    try await db.exec(raw: "INSERT INTO docs (data) VALUES (NULL)")

    let id = ColumnExpression<Int64>("id", of: "docs")
    let data = ColumnExpression<String>("data", of: "docs")
    let element = JSONEach(data)
    let rows = try await db.query(
      "SELECT \(id), \(element.key(as: Int.self)), \(element.value(as: Int.self)) FROM docs, \(element)"
    ) { stmt, _ in
      (
        try Int64.column(of: stmt, at: 0),
        try Int?.column(of: stmt, at: 1),
        try Int?.column(of: stmt, at: 2)
      )
    }

    // '[]' and NULL contribute no rows; the scalar root contributes one keyless row.
    #expect(rows.count == 1)
    #expect(rows.first?.0 == 2)
    #expect(rows.first?.1 == nil)
    #expect(rows.first?.2 == 7)
  }

  @Test("Alias with a quote followed by a combining scalar renders fully escaped")
  func testAliasCombiningScalarEscaping() throws {
    // Grapheme-level search would see `"` + U+0301 as a single character and skip the
    // quote; escaping must operate on Unicode scalars.
    let data = ColumnExpression<String>("data")
    let each = JSONEach(data, alias: "ali\"\u{301}as")
    var builder = SQLBuilder()
    each.append(to: &builder)

    #expect(builder.makeStatement().sql.hasSuffix(" AS \"ali\"\"\u{301}as\""))
  }
}
