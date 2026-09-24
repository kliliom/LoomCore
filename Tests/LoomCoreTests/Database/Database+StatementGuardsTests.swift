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
}
