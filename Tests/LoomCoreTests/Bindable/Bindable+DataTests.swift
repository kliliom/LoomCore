import Foundation
import LoomCore
import Testing

@Suite("Data Bindable Tests")
@DatabaseActor
struct BindableDataTests {
  @Test("Data binding and extraction")
  func testDataBinding() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (data BLOB)")

    let testData = Data([0x01, 0x02, 0x03, 0x04, 0x05])
    try db.exec("INSERT INTO test (data) VALUES (\(testData))")

    let result = try db.query("SELECT data FROM test") { stmt, _ in
      try Data.column(of: stmt, at: 0)
    }

    #expect(result.first == testData)
  }

  @Test("Empty Data")
  func testEmptyData() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (data BLOB)")

    let emptyData = Data()
    try db.exec("INSERT INTO test (data) VALUES (\(emptyData))")

    let result = try db.query("SELECT data FROM test") { stmt, _ in
      try Data.column(of: stmt, at: 0)
    }

    #expect(result.first == emptyData)
    #expect(result.first?.isEmpty == true)
  }

  @Test("Large Data")
  func testLargeData() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (data BLOB)")

    var largeData = Data(count: 10000)
    for i in 0..<10000 {
      largeData[i] = UInt8(i % 256)
    }

    try db.exec("INSERT INTO test (data) VALUES (\(largeData))")

    let result = try db.query("SELECT data FROM test") { stmt, _ in
      try Data.column(of: stmt, at: 0)
    }

    #expect(result.first == largeData)
    #expect(result.first?.count == 10000)
  }

  @Test("Data with all byte values")
  func testAllByteValues() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (data BLOB)")

    var allBytes = Data()
    for byte in 0...255 {
      allBytes.append(UInt8(byte))
    }

    try db.exec("INSERT INTO test (data) VALUES (\(allBytes))")

    let result = try db.query("SELECT data FROM test") { stmt, _ in
      try Data.column(of: stmt, at: 0)
    }

    #expect(result.first == allBytes)
    #expect(result.first?.count == 256)
  }

  @Test("Data as SQL literal")
  func testDataAsSQLLiteral() throws {
    let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
    let literal = try data.asSQLLiteral()

    #expect(literal == "X'deadbeef'")
  }

  @Test("Empty Data as SQL literal")
  func testEmptyDataAsSQLLiteral() throws {
    let data = Data()
    let literal = try data.asSQLLiteral()

    #expect(literal == "X''")
  }

  @Test("Data defaultSQLStorageType")
  func testDefaultSQLStorageType() {
    #expect(Data.defaultSQLStorageType == "BLOB")
  }

  @Test("Binary data round-trip")
  func testBinaryDataRoundTrip() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (data BLOB)")

    let binaryData = "Hello, World!".data(using: .utf8)!
    try db.exec("INSERT INTO test (data) VALUES (\(binaryData))")

    let result = try db.query("SELECT data FROM test") { stmt, _ in
      try Data.column(of: stmt, at: 0)
    }

    #expect(result.first == binaryData)
    #expect(String(data: result.first!, encoding: .utf8) == "Hello, World!")
  }

  @Test("Data throws unexpectedNullValue for NULL")
  func testDataUnexpectedNullValue() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (data BLOB)")
    try db.exec(raw: "INSERT INTO test (data) VALUES (NULL)")

    #expect(throws: LoomError.core(.nullValue, message: "Column at index 0 is NULL, cannot return Data.")) {
      try db.query("SELECT data FROM test") { stmt, _ in
        try Data.column(of: stmt, at: 0)
      }
    }
  }

  @Test("Data bind throws with connection error message on out-of-range index")
  func testDataBindOutOfRangeIndex() throws {
    let db = try Database.openInMemory()
    try db.exec("CREATE TABLE test (data BLOB)")

    let error = #expect(throws: LoomError.self) {
      try db.exec(
        raw: "INSERT INTO test (data) VALUES (?)",
        binder: { stmt in
          try Data([0x01, 0x02]).bind(to: stmt, at: 99)
        }
      )
    }
    let message = try #require(error?.message)
    #expect(!message.isEmpty)
  }
}
