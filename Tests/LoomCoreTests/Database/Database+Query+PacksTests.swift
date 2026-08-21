import Foundation
import LoomCore
import Testing

private let aliceCreatedAt = Date(timeIntervalSince1970: 1_700_000_000)
private let bobCreatedAt = Date(timeIntervalSince1970: 1_700_086_400)

/// Runs `body`, expecting it to fail with a `LoomError` carrying `code`.
@DatabaseActor
private func expectCoreError(
  _ code: LoomCoreErrorCode,
  performing body: @DatabaseActor () async throws -> Void,
  sourceLocation: SourceLocation = #_sourceLocation
) async {
  do {
    try await body()
    Issue.record("Expected a LoomError with code \(code)", sourceLocation: sourceLocation)
  } catch let error as LoomError {
    #expect(error.core == code, sourceLocation: sourceLocation)
  } catch {
    Issue.record("Expected a LoomError, got \(error)", sourceLocation: sourceLocation)
  }
}

/// Opens an in-memory database holding two users with every column populated.
@DatabaseActor
private func openPopulatedDatabase() async throws -> Database {
  let db = try Database.openInMemory()
  try await db.exec(
    "CREATE TABLE users (name TEXT, age INTEGER, created_at DOUBLE, email TEXT, nickname TEXT)"
  )
  try await db.exec(
    """
    INSERT INTO users (name, age, created_at, email, nickname)
    VALUES (\("Alice"), \(25), \(aliceCreatedAt), \("alice@example.com"), \("ali"))
    """
  )
  try await db.exec(
    """
    INSERT INTO users (name, age, created_at, email, nickname)
    VALUES (\("Bob"), \(30), \(bobCreatedAt), \("bob@example.com"), \(String?.none))
    """
  )
  return db
}

@Suite("Database Pack Query Tests")
@DatabaseActor
struct DatabasePackQueryTests {
  @Test("Query infers a tuple row from the return type")
  func testInfersTupleRowFromReturnType() async throws {
    let db = try await openPopulatedDatabase()

    let users: [(String, Int, Date)] = try await db.query(
      "SELECT name, age, created_at FROM users WHERE age >= \(18) ORDER BY age ASC"
    )

    #expect(users.count == 2)
    #expect(users[0] == ("Alice", 25, aliceCreatedAt))
    #expect(users[1] == ("Bob", 30, bobCreatedAt))
  }

  @Test("Query infers a single-column row as a bare value")
  func testInfersSingleColumnRow() async throws {
    let db = try await openPopulatedDatabase()

    let names: [String] = try await db.query("SELECT name FROM users ORDER BY name ASC")
    #expect(names == ["Alice", "Bob"])

    let ages: [Int] = try await db.query("SELECT age FROM users ORDER BY age ASC")
    #expect(ages == [25, 30])
  }

  @Test("Query reads columns positionally, not by name")
  func testReadsColumnsPositionally() async throws {
    let db = try await openPopulatedDatabase()

    let rows: [(Int, String)] = try await db.query("SELECT age, name FROM users ORDER BY age ASC")

    #expect(rows[0] == (25, "Alice"))
    #expect(rows[1] == (30, "Bob"))
  }

  @Test("Query decodes NULL into an optional element")
  func testDecodesOptionalElement() async throws {
    let db = try await openPopulatedDatabase()

    let rows: [(String, String?)] = try await db.query("SELECT name, nickname FROM users ORDER BY name ASC")

    #expect(rows[0] == ("Alice", "ali"))
    #expect(rows[1] == ("Bob", nil))
  }

  @Test("Query decodes Data and UUID elements")
  func testDecodesDataAndUUIDElements() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE blobs (id INTEGER, payload BLOB, token BLOB)")

    let payload = Data([0xDE, 0xAD, 0xBE, 0xEF])
    let token = UUID()
    try await db.exec("INSERT INTO blobs (id, payload, token) VALUES (\(1), \(payload), \(token))")

    let rows: [(Int, Data)] = try await db.query("SELECT id, payload FROM blobs")
    #expect(rows.count == 1)
    #expect(rows[0].0 == 1)
    #expect(rows[0].1 == payload)

    let tokens: [UUID] = try await db.query("SELECT token FROM blobs")
    #expect(tokens == [token])
  }

  @Test("Query throws when the row type has more elements than the result set")
  func testThrowsWhenRowTypeHasTooManyElements() async throws {
    let db = try await openPopulatedDatabase()

    do {
      let _: [(String, Int, Date)] = try await db.query("SELECT name, age FROM users")
      Issue.record("Expected a columnCountMismatch error")
    } catch let error as LoomError {
      #expect(error.core == .columnCountMismatch)
      // The message names both counts, so a mismatch says which side drifted.
      #expect(error.message == "Row type has 3 element(s) but the statement returns 2 column(s).")
    }
  }

  @Test("Query throws when the row type has fewer elements than the result set")
  func testThrowsWhenRowTypeHasTooFewElements() async throws {
    let db = try await openPopulatedDatabase()

    await expectCoreError(.columnCountMismatch) {
      let _: [(String, Int)] = try await db.query("SELECT name, age, email FROM users")
    }
  }

  @Test("Query throws rather than silently decoding a trailing optional element as nil")
  func testThrowsForOptionalTrailingElement() async throws {
    let db = try await openPopulatedDatabase()

    // An out-of-range column reads as NULL, which `Optional` would happily accept — the arity
    // check is the only thing standing between that and silently wrong data.
    await expectCoreError(.columnCountMismatch) {
      let _: [(String, Int, Double?)] = try await db.query("SELECT name, age FROM users")
    }
  }

  @Test("Query throws the column count mismatch before stepping any row")
  func testThrowsBeforeStepping() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    // No rows to step, so the check has to happen at bind time to fire at all.
    await expectCoreError(.columnCountMismatch) {
      let _: [(String, Int, Date)] = try await db.query("SELECT name, age FROM users")
    }
  }

  @Test("Query throws for a statement that returns no columns")
  func testThrowsForNonSelectStatement() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    await expectCoreError(.columnCountMismatch) {
      let _: [Int] = try await db.query("INSERT INTO users (name, age) VALUES (\("Alice"), \(25))")
    }
  }

  @Test("Query throws a null value error for NULL in a non-optional element")
  func testThrowsNullValueForNonOptionalElement() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER)")
    try await db.exec("INSERT INTO users (name, age) VALUES (\("Alice"), \(Int?.none))")

    // Distinct from a shape mismatch: the arity matches, the value doesn't.
    await expectCoreError(.nullValue) {
      let _: [(String, Int)] = try await db.query("SELECT name, age FROM users")
    }
  }

  @Test("Query returns an empty array for an empty result set")
  func testReturnsEmptyArrayForEmptyResultSet() async throws {
    let db = try await openPopulatedDatabase()

    let users: [(String, Int)] = try await db.query("SELECT name, age FROM users WHERE age > \(100)")

    #expect(users.isEmpty)
  }

  @Test("Query reads every row of the result set")
  func testReadsEveryRow() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE numbers (value INTEGER)")
    for value in 1...50 {
      try await db.exec("INSERT INTO numbers (value) VALUES (\(value))")
    }

    // These overloads have no `stop` parameter; callers needing early exit use `query(_:stepper:)`.
    let values: [Int] = try await db.query("SELECT value FROM numbers ORDER BY value ASC")

    #expect(values.count == 50)
    #expect(values.first == 1)
    #expect(values.last == 50)
  }

  @Test("Query with raw statement and no parameters")
  func testRawStatementWithoutParameters() async throws {
    let db = try await openPopulatedDatabase()

    let counts: [(Int, Int)] = try await db.query(
      raw: "SELECT age, COUNT(*) FROM users GROUP BY age ORDER BY age ASC"
    )

    #expect(counts.count == 2)
    #expect(counts[0] == (25, 1))
    #expect(counts[1] == (30, 1))
  }

  @Test("Query with raw statement throws on a column count mismatch")
  func testRawStatementThrowsOnColumnCountMismatch() async throws {
    let db = try await openPopulatedDatabase()

    await expectCoreError(.columnCountMismatch) {
      let _: [(String, Int)] = try await db.query(raw: "SELECT name FROM users")
    }
  }

  @Test("Query with SQLStatement interpolation binds every value")
  func testSQLStatementInterpolation() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER, status TEXT)")
    try await db.exec("INSERT INTO users VALUES (\("Alice"), \(25), \("active"))")
    try await db.exec("INSERT INTO users VALUES (\("Bob"), \(30), \("active"))")
    try await db.exec("INSERT INTO users VALUES (\("Carol"), \(35), \("archived"))")

    let minAge = 26
    let status = "active"
    let users: [(String, Int)] = try await db.query(
      "SELECT name, age FROM users WHERE age > \(minAge) AND status = \(status)"
    )

    #expect(users.count == 1)
    #expect(users[0] == ("Bob", 30))
  }

  @Test("Query infers a row type inside a transaction")
  func testInsideTransaction() async throws {
    let db = try await openPopulatedDatabase()

    let users: [(String, Int)] = try await db.transaction { db in
      try await db.exec("INSERT INTO users (name, age) VALUES (\("Dave"), \(40))")
      return try await db.query("SELECT name, age FROM users ORDER BY age ASC")
    }

    #expect(users.count == 3)
    #expect(users[2] == ("Dave", 40))
  }
}
