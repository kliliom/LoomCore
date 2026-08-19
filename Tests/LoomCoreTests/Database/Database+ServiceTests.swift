import Foundation
import LoomCore
import Testing

@Suite("Database Service Tests")
@DatabaseActor
struct DatabaseServiceTests {
  // Test service that tracks lifecycle calls
  @DatabaseActor
  class TrackingService: Database.Service {
    var willBeginCount = 0
    var didCommitCount = 0
    var didRollbackCount = 0
    var shutdownCalled = false

    override func transactionWillBegin() {
      willBeginCount += 1
    }

    override func transactionDidCommit() {
      didCommitCount += 1
    }

    override func transactionDidRollback() {
      didRollbackCount += 1
    }

    override func shutdown() {
      shutdownCalled = true
    }
  }

  @Test("Get service returns singleton instance")
  func testGetServiceReturnsSingleton() async throws {
    let db = try Database.openInMemory()

    let service1 = db.getService(TrackingService.self)
    let service2 = db.getService(TrackingService.self)

    #expect(service1 === service2)
  }

  @Test("Service has reference to database")
  func testServiceHasDatabaseReference() async throws {
    let db = try Database.openInMemory()

    let service = db.getService(TrackingService.self)

    #expect(service.database === db)
  }

  @Test("Service transactionWillBegin called before transaction")
  func testServiceTransactionWillBegin() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")

    let service = db.getService(TrackingService.self)

    #expect(service.willBeginCount == 0)

    try await db.transaction { db in
      try await db.exec("INSERT INTO test (value) VALUES (1)")
    }

    #expect(service.willBeginCount == 1)
  }

  @Test("Service transactionDidCommit called after successful transaction")
  func testServiceTransactionDidCommit() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")

    let service = db.getService(TrackingService.self)

    #expect(service.didCommitCount == 0)

    try await db.transaction { db in
      try await db.exec("INSERT INTO test (value) VALUES (1)")
    }

    #expect(service.didCommitCount == 1)
  }

  @Test("Service transactionDidRollback called on error")
  func testServiceTransactionDidRollback() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")

    let service = db.getService(TrackingService.self)

    #expect(service.didRollbackCount == 0)

    await #expect(throws: LoomError.self) {
      try await db.transaction { db in
        try await db.exec("INSERT INTO test (value) VALUES (1)")
        try await db.exec("INVALID SQL")
      }
    }

    #expect(service.didRollbackCount == 1)
  }

  @Test("Service receives callbacks for multiple transactions")
  func testServiceMultipleTransactions() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")

    let service = db.getService(TrackingService.self)

    // First transaction (success)
    try await db.transaction { db in
      try await db.exec("INSERT INTO test (value) VALUES (1)")
    }

    // Second transaction (success)
    try await db.transaction { db in
      try await db.exec("INSERT INTO test (value) VALUES (2)")
    }

    // Third transaction (failure)
    await #expect(throws: LoomError.self) {
      try await db.transaction { db in
        try await db.exec("INVALID SQL")
      }
    }

    #expect(service.willBeginCount == 3)
    #expect(service.didCommitCount == 2)
    #expect(service.didRollbackCount == 1)
  }

  @Test("Service shutdown is called")
  func testServiceShutdown() async throws {
    let db = try Database.openInMemory()

    let service = db.getService(TrackingService.self)

    #expect(service.shutdownCalled == false)

    db.shutdownService(TrackingService.self)

    #expect(service.shutdownCalled == true)
  }

  @Test("Service shutdown removes service from registry")
  func testServiceShutdownRemovesFromRegistry() async throws {
    let db = try Database.openInMemory()

    let service1 = db.getService(TrackingService.self)
    service1.willBeginCount = 999  // Mark this instance

    db.shutdownService(TrackingService.self)

    let service2 = db.getService(TrackingService.self)

    // Should be a new instance
    #expect(service2 !== service1)
    #expect(service2.willBeginCount == 0)
  }

  @Test("Multiple service types work independently")
  func testMultipleServiceTypes() async throws {
    @DatabaseActor
    class ServiceA: Database.Service {
      var callCount = 0
      override func transactionDidCommit() {
        callCount += 1
      }
    }

    @DatabaseActor
    class ServiceB: Database.Service {
      var callCount = 0
      override func transactionDidCommit() {
        callCount += 1
      }
    }

    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")

    let serviceA = db.getService(ServiceA.self)
    let serviceB = db.getService(ServiceB.self)

    try await db.transaction { db in
      try await db.exec("INSERT INTO test (value) VALUES (1)")
    }

    #expect(serviceA.callCount == 1)
    #expect(serviceB.callCount == 1)
  }

  @Test("Service can access database during callbacks")
  func testServiceCanAccessDatabaseDuringCallbacks() async throws {
    @DatabaseActor
    class LoggingService: Database.Service {
      var logEntries: [String] = []

      override func transactionDidCommit() {
        logEntries.append("Transaction committed")
      }
    }

    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")

    let service = db.getService(LoggingService.self)

    try await db.transaction { db in
      try await db.exec("INSERT INTO test (value) VALUES (1)")
    }

    #expect(service.logEntries.count == 1)
    #expect(service.logEntries[0] == "Transaction committed")
  }

  @Test("Service lifecycle for nested transactions")
  func testServiceLifecycleForNestedTransactions() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE test (value INTEGER)")

    let service = db.getService(TrackingService.self)

    // Outer transaction
    try await db.transaction { db in
      try await db.exec("INSERT INTO test (value) VALUES (1)")

      // Nested transactions open a SAVEPOINT scope inside the outer transaction; service
      // hooks describe the physical transaction, so only the outermost fires them.
      try await db.transaction { db in
        try await db.exec("INSERT INTO test (value) VALUES (2)")
      }
    }

    #expect(service.willBeginCount == 1)  // Only the outermost transaction begins
    #expect(service.didCommitCount == 1)  // One commit
    #expect(service.didRollbackCount == 0)  // No rollback
  }

  @Test("Service shut down mid-transaction receives no commit callback")
  func testServiceShutdownMidTransactionSkipsCommit() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE test (value INTEGER)")
    let service = db.getService(TrackingService.self)

    try await db.transaction { db in
      try await db.exec("INSERT INTO test (value) VALUES (1)")
      // Task.detached does not inherit the transaction token, and shutdownService is
      // ungated, so the shutdown provably completes while the transaction is in flight.
      await Task.detached { @DatabaseActor in
        db.shutdownService(TrackingService.self)
      }.value
    }

    #expect(service.willBeginCount == 1)
    #expect(service.shutdownCalled)
    // shutdown() is the service's final callback — no commit after it.
    #expect(service.didCommitCount == 0)
  }

  @Test("Service shut down mid-transaction receives no rollback callback")
  func testServiceShutdownMidTransactionSkipsRollback() async throws {
    struct BodyFailure: Error {}

    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE test (value INTEGER)")
    let service = db.getService(TrackingService.self)

    await #expect(throws: BodyFailure.self) {
      try await db.transaction { db in
        try await db.exec("INSERT INTO test (value) VALUES (1)")
        db.shutdownService(TrackingService.self)
        throw BodyFailure()
      }
    }

    #expect(service.willBeginCount == 1)
    #expect(service.shutdownCalled)
    // shutdown() is the service's final callback — no rollback after it.
    #expect(service.didRollbackCount == 0)
  }
}
