import Foundation
import LoomCore
import Testing

@Suite("Date Bindable Tests")
@DatabaseActor
struct BindableDateTests {
  @Test("Date binding and extraction")
  func testDateBinding() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (date DOUBLE)")

    let testDate = Date()
    try await db.exec("INSERT INTO test (date) VALUES (\(testDate))")

    let result = try await db.query("SELECT date FROM test") { stmt, _ in
      try Date.column(of: stmt, at: 0)
    }

    #expect(result.first != nil)
    #expect(abs(result.first!.timeIntervalSince(testDate)) < 0.001)
  }

  @Test("Specific Date value")
  func testSpecificDate() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (date DOUBLE)")

    let specificDate = Date(timeIntervalSince1970: 1234567890.0)
    try await db.exec("INSERT INTO test (date) VALUES (\(specificDate))")

    let result = try await db.query("SELECT date FROM test") { stmt, _ in
      try Date.column(of: stmt, at: 0)
    }

    #expect(result.first == specificDate)
    #expect(result.first?.timeIntervalSince1970 == 1234567890.0)
  }

  @Test("Date distant past and future")
  func testDistantDates() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (date DOUBLE)")

    let distantPast = Date.distantPast
    try await db.exec("INSERT INTO test (date) VALUES (\(distantPast))")

    let resultPast = try await db.query("SELECT date FROM test") { stmt, _ in
      try Date.column(of: stmt, at: 0)
    }
    #expect(resultPast.first?.timeIntervalSince1970 == distantPast.timeIntervalSince1970)

    try await db.exec("DELETE FROM test")

    let distantFuture = Date.distantFuture
    try await db.exec("INSERT INTO test (date) VALUES (\(distantFuture))")

    let resultFuture = try await db.query("SELECT date FROM test") { stmt, _ in
      try Date.column(of: stmt, at: 0)
    }
    #expect(resultFuture.first?.timeIntervalSince1970 == distantFuture.timeIntervalSince1970)
  }

  @Test("Date as SQL literal")
  func testDateAsSQLLiteral() async throws {
    let date = Date(timeIntervalSince1970: 1234567890.5)
    let literal = try date.asSQLLiteral()

    #expect(literal == "1234567890.5")
  }

  @Test("Date defaultSQLStorageType")
  func testDefaultSQLStorageType() {
    #expect(Date.defaultSQLStorageType == "DOUBLE")
  }

  @Test("Multiple dates ordering")
  func testMultipleDatesOrdering() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (date DOUBLE)")

    let date1 = Date(timeIntervalSince1970: 1000)
    let date2 = Date(timeIntervalSince1970: 2000)
    let date3 = Date(timeIntervalSince1970: 3000)

    try await db.exec("INSERT INTO test (date) VALUES (\(date2))")
    try await db.exec("INSERT INTO test (date) VALUES (\(date1))")
    try await db.exec("INSERT INTO test (date) VALUES (\(date3))")

    let results = try await db.query("SELECT date FROM test ORDER BY date ASC") { stmt, _ in
      try Date.column(of: stmt, at: 0)
    }

    #expect(results.count == 3)
    #expect(results[0].timeIntervalSince1970 == 1000)
    #expect(results[1].timeIntervalSince1970 == 2000)
    #expect(results[2].timeIntervalSince1970 == 3000)
  }

  @Test("Date with fractional seconds")
  func testDateWithFractionalSeconds() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (date DOUBLE)")

    let dateWithFraction = Date(timeIntervalSince1970: 1234567890.123456)
    try await db.exec("INSERT INTO test (date) VALUES (\(dateWithFraction))")

    let result = try await db.query("SELECT date FROM test") { stmt, _ in
      try Date.column(of: stmt, at: 0)
    }

    #expect(result.first != nil)
    #expect(abs(result.first!.timeIntervalSince1970 - 1234567890.123456) < 0.000001)
  }

  @Test("Date range queries")
  func testDateRangeQueries() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE events (date DOUBLE, name TEXT)")

    let now = Date()
    let yesterday = Date(timeIntervalSinceNow: -86400)
    let tomorrow = Date(timeIntervalSinceNow: 86400)

    try await db.exec("INSERT INTO events (date, name) VALUES (\(yesterday), 'past')")
    try await db.exec("INSERT INTO events (date, name) VALUES (\(now), 'present')")
    try await db.exec("INSERT INTO events (date, name) VALUES (\(tomorrow), 'future')")

    let futureEvents = try await db.query("SELECT name FROM events WHERE date > \(now)") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(futureEvents.count == 1)
    #expect(futureEvents.first == "future")
  }
}
