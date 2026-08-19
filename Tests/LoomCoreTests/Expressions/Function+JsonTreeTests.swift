import Foundation
import LoomCore
import Testing

@Suite("Function JsonTree Tests")
@DatabaseActor
struct FunctionJsonTreeTests {
  @Test("Walks nested containers recursively")
  func testRecursiveWalk() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE docs (data TEXT)")
    try await db.exec(raw: #"INSERT INTO docs (data) VALUES ('{"a":{"b":1}}')"#)

    let data = ColumnExpression<String>("data", of: "docs")
    let node = JSONTree(data)
    let result = try await db.query(
      "SELECT \(node.fullkey), \(node.type) FROM docs, \(node) ORDER BY \(node.id)"
    ) { stmt, _ in
      (try String.column(of: stmt, at: 0), try String.column(of: stmt, at: 1))
    }

    #expect(result.count == 3)
    #expect(result[0] == ("$", "object"))
    #expect(result[1] == ("$.a", "object"))
    #expect(result[2] == ("$.a.b", "integer"))
  }

  @Test("parent links nodes to their container; root parent is NULL")
  func testParentLinks() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE docs (data TEXT)")
    try await db.exec(raw: #"INSERT INTO docs (data) VALUES ('{"a":1}')"#)

    let data = ColumnExpression<String>("data", of: "docs")
    let node = JSONTree(data, alias: "node")
    let result = try await db.query(
      "SELECT \(node.parent), \(node.id) FROM docs, \(node) ORDER BY \(node.id)"
    ) { stmt, _ in
      (try Int?.column(of: stmt, at: 0), try Int.column(of: stmt, at: 1))
    }

    #expect(result.count == 2)
    #expect(result[0].0 == nil)  // root
    #expect(result[1].0 == result[0].1)  // leaf points at root
  }

  @Test("Path-scoped walk")
  func testPathScopedWalk() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE docs (data TEXT)")
    try await db.exec(raw: #"INSERT INTO docs (data) VALUES ('{"skip":1,"take":{"x":2}}')"#)

    let data = ColumnExpression<String>("data", of: "docs")
    let node = JSONTree(data, "$.take")
    let result = try await db.query(
      "SELECT \(node.fullkey) FROM docs, \(node) ORDER BY \(node.id)"
    ) { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result == ["$.take", "$.take.x"])
  }

  @Test("Typed value handle on scalar leaves")
  func testTypedValues() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE docs (data TEXT)")
    try await db.exec(raw: #"INSERT INTO docs (data) VALUES ('[10,20]')"#)

    let data = ColumnExpression<String>("data", of: "docs")
    let node = JSONTree(data)
    let leaves = try await db.query(
      "SELECT \(node.value(as: Int.self)) FROM docs, \(node) WHERE \(node.type == "integer") ORDER BY \(node.id)"
    ) { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(leaves == [10, 20])
  }

  @Test("key, atom and path handles read each node")
  func testKeyAtomPathHandles() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE docs (data TEXT)")
    try await db.exec(raw: #"INSERT INTO docs (data) VALUES ('{"a":{"b":7}}')"#)

    let data = ColumnExpression<String>("data", of: "docs")
    let node = JSONTree(data)
    let rows = try await db.query(
      "SELECT \(node.key(as: String.self)), \(node.atom(as: Int.self)), \(node.path) FROM docs, \(node) ORDER BY \(node.id)"
    ) { stmt, _ in
      (
        try String?.column(of: stmt, at: 0),
        try Int?.column(of: stmt, at: 1),
        try String.column(of: stmt, at: 2)
      )
    }

    #expect(rows.count == 3)
    #expect(rows[0] == (nil, nil, "$"))  // root container
    #expect(rows[1] == ("a", nil, "$"))  // nested container: atom is NULL
    #expect(rows[2] == ("b", 7, "$.a"))  // scalar leaf
  }

  @Test("Empty container, scalar root, and NULL source row counts")
  func testRowCountEdgeCases() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE docs (id INTEGER PRIMARY KEY, data TEXT)")
    try await db.exec(raw: "INSERT INTO docs (data) VALUES ('{}')")
    try await db.exec(raw: "INSERT INTO docs (data) VALUES (NULL)")

    let id = ColumnExpression<Int64>("id", of: "docs")
    let data = ColumnExpression<String>("data", of: "docs")
    let node = JSONTree(data)
    let rows = try await db.query(
      "SELECT \(id), \(node.type) FROM docs, \(node)"
    ) { stmt, _ in
      (try Int64.column(of: stmt, at: 0), try String.column(of: stmt, at: 1))
    }

    // Unlike json_each, json_tree yields the container itself: '{}' is one root row.
    // A NULL document contributes no rows.
    #expect(rows.count == 1)
    #expect(rows.first?.0 == 1)
    #expect(rows.first?.1 == "object")
  }

  @Test("Alias with a quote followed by a combining scalar renders fully escaped")
  func testAliasCombiningScalarEscaping() throws {
    // Grapheme-level search would see `"` + U+0301 as a single character and skip the
    // quote; escaping must operate on Unicode scalars.
    let data = ColumnExpression<String>("data")
    let node = JSONTree(data, alias: "ali\"\u{301}as")
    var builder = SQLBuilder()
    node.append(to: &builder)

    #expect(builder.makeStatement().sql.hasSuffix(" AS \"ali\"\"\u{301}as\""))
  }
}
