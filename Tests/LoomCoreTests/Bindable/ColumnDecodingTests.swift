import Foundation
import LoomCore
import Testing

@Suite("Column Decoding Policy Tests")
@DatabaseActor
struct ColumnDecodingTests {
  @Test("NULL throws nullValue for every non-optional numeric type")
  func testNullThrowsForNumericTypes() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")
    try await db.exec(raw: "INSERT INTO test (value) VALUES (NULL)")

    await #expect(throws: LoomError.core(.nullValue, message: "Column at index 0 is NULL, cannot return Int.")) {
      try await db.query("SELECT value FROM test") { stmt, _ in try Int.column(of: stmt, at: 0) }
    }
    await #expect(throws: LoomError.core(.nullValue, message: "Column at index 0 is NULL, cannot return Int32.")) {
      try await db.query("SELECT value FROM test") { stmt, _ in try Int32.column(of: stmt, at: 0) }
    }
    await #expect(throws: LoomError.core(.nullValue, message: "Column at index 0 is NULL, cannot return Int64.")) {
      try await db.query("SELECT value FROM test") { stmt, _ in try Int64.column(of: stmt, at: 0) }
    }
    await #expect(throws: LoomError.core(.nullValue, message: "Column at index 0 is NULL, cannot return Bool.")) {
      try await db.query("SELECT value FROM test") { stmt, _ in try Bool.column(of: stmt, at: 0) }
    }
    await #expect(throws: LoomError.core(.nullValue, message: "Column at index 0 is NULL, cannot return Float.")) {
      try await db.query("SELECT value FROM test") { stmt, _ in try Float.column(of: stmt, at: 0) }
    }
    await #expect(throws: LoomError.core(.nullValue, message: "Column at index 0 is NULL, cannot return Double.")) {
      try await db.query("SELECT value FROM test") { stmt, _ in try Double.column(of: stmt, at: 0) }
    }
    await #expect(throws: LoomError.core(.nullValue, message: "Column at index 0 is NULL, cannot return Date.")) {
      try await db.query("SELECT value FROM test") { stmt, _ in try Date.column(of: stmt, at: 0) }
    }
  }

  @Test("TEXT storage throws typeMappingFailed for integer types")
  func testTextThrowsForIntegerTypes() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value TEXT)")
    try await db.exec(raw: "INSERT INTO test (value) VALUES ('42')")

    await #expect(
      throws: LoomError.core(
        .typeMappingFailed,
        message: "Column at index 0 has storage class TEXT, cannot return Int."
      )
    ) {
      try await db.query("SELECT value FROM test") { stmt, _ in try Int.column(of: stmt, at: 0) }
    }
    await #expect(throws: LoomError.self) {
      try await db.query("SELECT value FROM test") { stmt, _ in try Int64.column(of: stmt, at: 0) }
    }
    await #expect(throws: LoomError.self) {
      try await db.query("SELECT value FROM test") { stmt, _ in try Bool.column(of: stmt, at: 0) }
    }
  }

  @Test("REAL storage throws typeMappingFailed for integer types")
  func testRealThrowsForIntegerTypes() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value DOUBLE)")
    try await db.exec(raw: "INSERT INTO test (value) VALUES (1.5)")

    await #expect(
      throws: LoomError.core(
        .typeMappingFailed,
        message: "Column at index 0 has storage class REAL, cannot return Int."
      )
    ) {
      try await db.query("SELECT value FROM test") { stmt, _ in try Int.column(of: stmt, at: 0) }
    }
  }

  @Test("INTEGER storage widens into Double and Float")
  func testIntegerWidensIntoFloatingPoint() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")
    try await db.exec(raw: "INSERT INTO test (value) VALUES (42)")

    let doubles = try await db.query("SELECT value FROM test") { stmt, _ in try Double.column(of: stmt, at: 0) }
    #expect(doubles.first == 42.0)

    let floats = try await db.query("SELECT value FROM test") { stmt, _ in try Float.column(of: stmt, at: 0) }
    #expect(floats.first == 42.0)
  }

  @Test("TEXT and BLOB storage throw typeMappingFailed for floating-point types")
  func testTextAndBlobThrowForFloatingPointTypes() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value)")
    try await db.exec(raw: "INSERT INTO test (value) VALUES ('1.5')")
    try await db.exec(raw: "INSERT INTO test (value) VALUES (X'DEADBEEF')")

    await #expect(
      throws: LoomError.core(
        .typeMappingFailed,
        message: "Column at index 0 has storage class TEXT, cannot return Double."
      )
    ) {
      try await db.query("SELECT value FROM test WHERE typeof(value) = 'text'") { stmt, _ in
        try Double.column(of: stmt, at: 0)
      }
    }
    await #expect(
      throws: LoomError.core(
        .typeMappingFailed,
        message: "Column at index 0 has storage class BLOB, cannot return Double."
      )
    ) {
      try await db.query("SELECT value FROM test WHERE typeof(value) = 'blob'") { stmt, _ in
        try Double.column(of: stmt, at: 0)
      }
    }
  }

  @Test("INTEGER storage throws typeMappingFailed for String")
  func testIntegerThrowsForString() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")
    try await db.exec(raw: "INSERT INTO test (value) VALUES (42)")

    await #expect(
      throws: LoomError.core(
        .typeMappingFailed,
        message: "Column at index 0 has storage class INTEGER, cannot return String."
      )
    ) {
      try await db.query("SELECT value FROM test") { stmt, _ in try String.column(of: stmt, at: 0) }
    }
  }

  @Test("INTEGER storage throws typeMappingFailed for Data")
  func testIntegerThrowsForData() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")
    try await db.exec(raw: "INSERT INTO test (value) VALUES (42)")

    await #expect(
      throws: LoomError.core(
        .typeMappingFailed,
        message: "Column at index 0 has storage class INTEGER, cannot return Data."
      )
    ) {
      try await db.query("SELECT value FROM test") { stmt, _ in try Data.column(of: stmt, at: 0) }
    }
  }

  @Test("TEXT storage reads into Data as UTF-8 bytes")
  func testTextReadsIntoData() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value TEXT)")
    try await db.exec(raw: "INSERT INTO test (value) VALUES ('abc')")

    let result = try await db.query("SELECT value FROM test") { stmt, _ in try Data.column(of: stmt, at: 0) }
    #expect(result.first == Data("abc".utf8))
  }

  @Test("Out-of-range INTEGER throws typeMappingFailed for Int32")
  func testInt32Overflow() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")
    try await db.exec(raw: "INSERT INTO test (value) VALUES (9223372036854775807)")

    await #expect(
      throws: LoomError.core(
        .typeMappingFailed,
        message: "Column at index 0 holds 9223372036854775807, which is out of range for Int32."
      )
    ) {
      try await db.query("SELECT value FROM test") { stmt, _ in try Int32.column(of: stmt, at: 0) }
    }
  }
}
