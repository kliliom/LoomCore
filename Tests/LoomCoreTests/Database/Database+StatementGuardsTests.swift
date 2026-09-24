import Foundation
import LoomCore
import Testing

@Suite("Database Statement Guard Tests")
@DatabaseActor
struct DatabaseStatementGuardsTests {
  // MARK: - Auto-rolled-back transactions

  // After `ON CONFLICT ROLLBACK` rolls the physical transaction back, a body that swallows
  // the error must not keep writing in autocommit mode — those writes would be durable while
  // the scope reports a rollback.
  @Test("Statements after an auto-rollback throw instead of autocommitting")
  func testStatementAfterAutoRollbackThrows() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE test (value INTEGER PRIMARY KEY ON CONFLICT ROLLBACK)")
    try await db.exec("INSERT INTO test (value) VALUES (1)")

    await #expect(throws: LoomError.self) {
      try await db.transaction { db in
        try await db.exec("INSERT INTO test (value) VALUES (2)")
        try? await db.exec("INSERT INTO test (value) VALUES (1)")
        do {
          try await db.exec("INSERT INTO test (value) VALUES (3)")
          Issue.record("Write after auto-rollback should throw")
        } catch let error as LoomError {
          #expect(error.core == .transactionScopeLost)
        }
        _ = try await db.query("SELECT value FROM test") { stmt, _ in try Int.column(of: stmt, at: 0) }
      }
    }

    let values = try await db.query("SELECT value FROM test ORDER BY value") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(values == [1])
  }

  @Test("Nested transaction after an auto-rollback does not open a new transaction")
  func testSavepointAfterAutoRollbackThrows() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE test (value INTEGER PRIMARY KEY ON CONFLICT ROLLBACK)")
    try await db.exec("INSERT INTO test (value) VALUES (1)")

    await #expect(throws: LoomError.self) {
      try await db.transaction { db in
        try? await db.exec("INSERT INTO test (value) VALUES (1)")
        try? await db.transaction { db in
          try await db.exec(raw: "INSERT INTO test (value) VALUES (4)")
        }
      }
    }

    let values = try await db.query("SELECT value FROM test ORDER BY value") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(values == [1])

    // No invisible transaction was left open behind the gate.
    try await db.transaction { db in
      try await db.exec("INSERT INTO test (value) VALUES (5)")
    }
  }

  // MARK: - Parameter count

  @Test("A stray placeholder in interpolated SQL throws instead of binding NULL")
  func testStrayPlaceholderThrows() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE test (a INTEGER, b INTEGER)")
    let b = 2

    await expectCoreError(.parameterCountMismatch) {
      try await db.exec("INSERT INTO test (a, b) VALUES (?, \(b))")
    }
    await expectCoreError(.parameterCountMismatch) {
      _ = try await db.query("SELECT a FROM test WHERE a = ? AND b = \(b)") { stmt, _ in 0 }
    }
    await expectCoreError(.parameterCountMismatch) {
      try await db.exec(raw: "INSERT INTO test (a, b) VALUES (?, ?)", binding: 1)
    }
    await expectCoreError(.parameterCountMismatch) {
      _ = try await db.query(raw: "SELECT a FROM test WHERE a = ? AND b = ?", binding: 1) { stmt, _, _ in 0 }
    }

    let count = try await db.query("SELECT COUNT(*) FROM test") { stmt, _ in try Int.column(of: stmt, at: 0) }
    #expect(count == [0])
  }

  @Test("Reused numbered parameters count once")
  func testNumberedParametersCountOnce() async throws {
    let db = try Database.openInMemory()
    let values = try await db.query(raw: "SELECT ?1 + ?1", binding: 2) { stmt, _, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(values == [4])
  }
}

/// Expects `body` to throw a `LoomError` carrying the given core code.
@DatabaseActor
private func expectCoreError(
  _ code: LoomCoreErrorCode,
  sourceLocation: SourceLocation = #_sourceLocation,
  _ body: @DatabaseActor () async throws -> Void
) async {
  let error = await #expect(throws: LoomError.self, sourceLocation: sourceLocation) {
    try await body()
  }
  #expect(error?.core == code, sourceLocation: sourceLocation)
}
