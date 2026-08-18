import Foundation
import LoomCore
import Testing

@Suite("TextDate Bindable Tests")
@DatabaseActor
struct BindableTextDateTests {
  @Test("TextDate round-trips through a TEXT column as datetime text")
  func testTextDateRoundTrip() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE events (created_at TEXT)")

    let date = TextDate(Date(timeIntervalSince1970: 1_786_786_200.5))
    try await db.exec("INSERT INTO events (created_at) VALUES (\(date))")

    let result = try await db.query("SELECT created_at, typeof(created_at) FROM events") { stmt, _ in
      (try TextDate.column(of: stmt, at: 0), try String.column(of: stmt, at: 1), try String.column(of: stmt, at: 0))
    }
    let (decoded, storage, stored) = try #require(result.first)

    #expect(storage == "text")
    #expect(stored == "2026-08-15 09:30:00.500")
    #expect(decoded == date)
  }

  @Test("TextDate truncates sub-millisecond precision on bind")
  func testTextDateTruncatesSubMilliseconds() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value TEXT)")
    try await db.exec("INSERT INTO test (value) VALUES (\(TextDate(Date(timeIntervalSince1970: 1_786_786_200.7509))))")

    let result = try await db.query("SELECT value FROM test") { stmt, _ in
      try TextDate.column(of: stmt, at: 0)
    }

    #expect(result.first?.date == Date(timeIntervalSince1970: 1_786_786_200.75))
  }

  @Test("TextDate decodes SQLite datetime text variants")
  func testTextDateDecodesTextVariants() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value TEXT)")

    let cases: [(text: String, epoch: Double)] = [
      ("2026-08-15 09:30:00", 1_786_786_200),
      ("2026-08-15T09:30:00Z", 1_786_786_200),
      ("2026-08-15 09:30:00.500", 1_786_786_200.5),
      ("2026-08-15 09:30:00.5", 1_786_786_200.5),
      ("2026-08-15 09:30:00.50", 1_786_786_200.5),
      ("2026-08-15 09:30:00+02:00", 1_786_779_000),
      ("2026-08-15 09:30:00-02:00", 1_786_793_400),
      ("2026-08-15 09:30", 1_786_786_200),
      ("2026-08-15 09:30+02:00", 1_786_779_000),
      ("2026-08-15", 1_786_752_000),
      ("2026-08-15 09:30:00.75099", 1_786_786_200.75),
    ]
    for (text, epoch) in cases {
      try await db.exec(raw: "DELETE FROM test")
      try await db.exec("INSERT INTO test (value) VALUES (\(text))")

      let result = try await db.query("SELECT value FROM test") { stmt, _ in
        try TextDate.column(of: stmt, at: 0)
      }

      #expect(result.first?.date.timeIntervalSince1970 == epoch, "decoding \(text)")
    }
  }

  @Test("TextDate reads CURRENT_TIMESTAMP defaults")
  func testTextDateReadsCurrentTimestamp() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE events (created_at TEXT DEFAULT CURRENT_TIMESTAMP)")
    try await db.exec(raw: "INSERT INTO events DEFAULT VALUES")

    let result = try await db.query("SELECT created_at, created_at FROM events") { stmt, _ in
      (try String.column(of: stmt, at: 0), try TextDate.column(of: stmt, at: 1))
    }
    let (stored, decoded) = try #require(result.first)

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.timeZone = TimeZone(identifier: "UTC")
    let expected = try #require(formatter.date(from: stored))

    #expect(decoded.date == expected)
  }

  @Test("TextDate compares correctly against CURRENT_TIMESTAMP values in SQL")
  func testTextDateComparesInSQL() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE events (name TEXT, created_at TEXT DEFAULT CURRENT_TIMESTAMP)")
    try await db.exec(raw: "INSERT INTO events (name) VALUES ('now')")
    try await db.exec(
      "INSERT INTO events (name, created_at) VALUES (\("past"), \(TextDate(Date(timeIntervalSince1970: 0))))"
    )
    try await db.exec(
      "INSERT INTO events (name, created_at) VALUES (\("future"), \(TextDate(Date().addingTimeInterval(3600))))"
    )

    let cutoff = Date().addingTimeInterval(-3600).textDate
    let recent = try await db.query("SELECT name FROM events WHERE created_at > \(cutoff) ORDER BY created_at") {
      stmt,
      _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(recent == ["now", "future"])
  }

  @Test("TextDate SQL literal is a quoted datetime string")
  func testTextDateSQLLiteral() async throws {
    let literal = try TextDate(Date(timeIntervalSince1970: 1_786_786_200.5)).asSQLLiteral()
    #expect(literal == "'2026-08-15 09:30:00.500'")
  }

  @Test("TextDate default storage type is TEXT")
  func testTextDateStorageType() async throws {
    #expect(TextDate.defaultSQLStorageType == "TEXT")
  }

  @Test("Date.textDate wraps the date")
  func testDateTextDateConvenience() async throws {
    let date = Date(timeIntervalSince1970: 1_786_786_200.5)
    #expect(date.textDate == TextDate(date))
    #expect(date.textDate.date == date)
  }

  @Test("TextDate compares by its underlying date")
  func testTextDateComparable() async throws {
    let earlier = TextDate(Date(timeIntervalSince1970: 1_786_786_200))
    let later = TextDate(Date(timeIntervalSince1970: 1_786_786_201))
    #expect(earlier < later)
    #expect([later, earlier].sorted() == [earlier, later])
  }

  @Test("TextDate encodes and decodes as its underlying date")
  func testTextDateCodable() async throws {
    let value = TextDate(Date(timeIntervalSince1970: 1_786_786_200.5))

    let encoded = try JSONEncoder().encode(value)
    #expect(encoded == (try JSONEncoder().encode(value.date)))

    let decoded = try JSONDecoder().decode(TextDate.self, from: encoded)
    #expect(decoded == value)
  }

  @Test("TextDate throws nullValue for NULL")
  func testTextDateNull() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value TEXT)")
    try await db.exec(raw: "INSERT INTO test (value) VALUES (NULL)")

    await #expect(throws: LoomError.core(.nullValue, message: "Column at index 0 is NULL, cannot return TextDate.")) {
      try await db.query("SELECT value FROM test") { stmt, _ in
        try TextDate.column(of: stmt, at: 0)
      }
    }

    let optional = try await db.query("SELECT value FROM test") { stmt, _ in
      try TextDate?.column(of: stmt, at: 0)
    }
    #expect(optional.first == .some(nil))
  }

  @Test("TextDate throws typeMappingFailed for non-TEXT storage")
  func testTextDateRejectsNonTextStorage() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value)")
    try await db.exec(raw: "INSERT INTO test (value) VALUES (1786786200.5)")

    await #expect(
      throws: LoomError.core(
        .typeMappingFailed,
        message: "Column at index 0 has storage class REAL, cannot return TextDate."
      )
    ) {
      try await db.query("SELECT value FROM test") { stmt, _ in
        try TextDate.column(of: stmt, at: 0)
      }
    }
  }

  @Test("TextDate throws typeMappingFailed for unparseable text")
  func testTextDateUnparseableText() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value TEXT)")
    try await db.exec(raw: "INSERT INTO test (value) VALUES ('not a date')")

    await #expect(
      throws: LoomError.core(
        .typeMappingFailed,
        message: "Column at index 0 holds \"not a date\", which is not a recognized datetime, cannot return TextDate."
      )
    ) {
      try await db.query("SELECT value FROM test") { stmt, _ in
        try TextDate.column(of: stmt, at: 0)
      }
    }
  }
}
