import Foundation
import Testing

@testable import LoomCore

@Suite("Database Pragmas Tests")
@DatabaseActor
class DatabasePragmasTests {

  let url: URL
  let db: Database

  init() async throws {
    url = tmpDatabaseURL()
    db = try Database.open(url: url)
  }

  deinit {
    Task { @DatabaseActor [db, url] in
      db.close()
      url.remove()
    }
  }

  // MARK: - Journal Mode Tests

  @Test("Get and set journal mode")
  func testJournalMode() async throws {
    // Default should be DELETE for in-memory databases
    let defaultMode = try await db.getJournalMode()
    #expect(defaultMode == .memory || defaultMode == .delete)

    // Set to WAL
    let walMode = try await db.setJournalMode(.wal)
    #expect(walMode == .wal)

    // Verify it was set
    let currentMode = try await db.getJournalMode()
    #expect(currentMode == .wal)

    // Try other modes
    _ = try await db.setJournalMode(.memory)
    #expect(try await db.getJournalMode() == .memory)

    _ = try await db.setJournalMode(.persist)
    #expect(try await db.getJournalMode() == .persist)
  }

  // MARK: - Synchronous Mode Tests

  @Test("Get and set synchronous mode")
  func testSynchronousMode() async throws {
    // Default should be FULL
    let defaultMode = try await db.getSynchronous()
    #expect(defaultMode == .full)

    // Set to NORMAL
    try await db.setSynchronous(.normal)
    #expect(try await db.getSynchronous() == .normal)

    // Try other modes
    try await db.setSynchronous(.off)
    #expect(try await db.getSynchronous() == .off)

    try await db.setSynchronous(.extra)
    #expect(try await db.getSynchronous() == .extra)
  }

  // MARK: - Cache Size Tests

  @Test("Get and set cache size")
  func testCacheSize() async throws {
    // Get default cache size
    let defaultSize = try await db.getCacheSize()
    #expect(defaultSize != .pages(0) && defaultSize != .kibibytes(0))

    // Set cache size in pages
    try await db.setCacheSize(.pages(5000))
    #expect(try await db.getCacheSize() == .pages(5000))

    // Set cache size in kibibytes
    try await db.setCacheSize(.kibibytes(10240))  // 10MB
    #expect(try await db.getCacheSize() == .kibibytes(10240))
  }

  // MARK: - Temp Store Tests

  @Test("Get and set temp store mode")
  func testTempStoreMode() async throws {
    // Get default temp store
    let defaultMode = try await db.getTempStore()
    #expect(defaultMode == .default || defaultMode == .file || defaultMode == .memory)

    // Set to memory
    try await db.setTempStore(.memory)
    #expect(try await db.getTempStore() == .memory)

    // Set to file
    try await db.setTempStore(.file)
    #expect(try await db.getTempStore() == .file)
  }

  // MARK: - Memory-Mapped I/O Tests

  @Test("Get and set mmap size")
  func testMmapSize() async throws {
    // Get default mmap size
    let defaultSize = try await db.getMmapSize()
    #expect(defaultSize >= 0)

    // Set mmap size to 256MB
    #expect(try await db.setMmapSize(10 * 1024 * 1024) == 10 * 1024 * 1024)
    #expect(try await db.getMmapSize() == 10 * 1024 * 1024)

    // Disable mmap
    #expect(try await db.setMmapSize(0) == 0)
    #expect(try await db.getMmapSize() == 0)
  }

  // MARK: - Foreign Keys Tests

  @Test("Get and set foreign keys enforcement")
  func testForeignKeys() async throws {
    // Default should be disabled
    #expect(try await db.getForeignKeys() == false)

    // Enable foreign keys
    try await db.setForeignKeys(true)
    #expect(try await db.getForeignKeys() == true)

    // Disable foreign keys
    try await db.setForeignKeys(false)
    #expect(try await db.getForeignKeys() == false)
  }

  @Test("Foreign keys prevent invalid inserts when enabled")
  func testForeignKeysEnforcement() async throws {
    try await db.setForeignKeys(true)

    // Create parent and child tables
    try await db.exec(
      """
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL
      )
      """
    )

    try await db.exec(
      """
      CREATE TABLE posts (
        id INTEGER PRIMARY KEY,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
      """
    )

    // Insert valid user
    try await db.exec(raw: "INSERT INTO users (id, name) VALUES (?, ?)", binding: 1, "Alice")

    // This should succeed
    try await db.exec(raw: "INSERT INTO posts (user_id, title) VALUES (?, ?)", binding: 1, "Post 1")

    // This should fail (user_id 999 doesn't exist)
    await #expect(throws: LoomError.self) {
      try await db.exec(raw: "INSERT INTO posts (user_id, title) VALUES (?, ?)", binding: 999, "Post 2")
    }
  }

  // MARK: - Auto Vacuum Tests

  @Test("Get and set auto vacuum mode")
  func testAutoVacuumMode() async throws {
    // Default should be NONE
    #expect(try await db.getAutoVacuum() == .none)

    // Set to incremental (requires VACUUM to take effect)
    try await db.setAutoVacuum(.incremental)
    try await db.vacuum()
    #expect(try await db.getAutoVacuum() == .incremental)
  }

  // MARK: - Maintenance Operations Tests

  @Test("Integrity check on healthy database")
  func testIntegrityCheckHealthy() async throws {
    // Create a simple table
    try await db.exec(
      """
      CREATE TABLE test (
        id INTEGER PRIMARY KEY,
        value TEXT
      )
      """
    )

    try await db.exec(raw: "INSERT INTO test (value) VALUES (?)", binding: "test data")

    // Should return empty array (no issues)
    let issues = try await db.integrityCheck()
    #expect(issues.isEmpty)
  }

  @Test("Optimize database")
  func testOptimize() async throws {
    // Create some tables and data
    try await db.exec(
      """
      CREATE TABLE test (
        id INTEGER PRIMARY KEY,
        value TEXT
      )
      """
    )

    for i in 0..<100 {
      try await db.exec(raw: "INSERT INTO test (value) VALUES (?)", binding: "value \(i)")
    }

    // Optimize should not throw
    try await db.optimize()
  }

  @Test("Vacuum database")
  func testVacuum() async throws {
    // Create table and data
    try await db.exec(
      """
      CREATE TABLE test (
        id INTEGER PRIMARY KEY,
        value TEXT
      )
      """
    )

    for i in 0..<1000 {
      try await db.exec(raw: "INSERT INTO test (value) VALUES (?)", binding: "value \(i)")
    }

    // Delete half the data
    try await db.exec("DELETE FROM test WHERE id % 2 = 0")

    // Get database size before vacuum
    let sizeBefore = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64

    // Vacuum should reclaim space
    try await db.vacuum()

    // Get database size after vacuum
    let sizeAfter = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64

    // Size should be reduced (or at least not increased)
    if let before = sizeBefore, let after = sizeAfter {
      #expect(after <= before)
    }

    // Verify data integrity after vacuum
    let count = try await db.query("SELECT COUNT(*) FROM test") { stmt, _ in
      try Int32.column(of: stmt, at: 0)
    }
    #expect(count.first == 500)
  }

  @Test("Incremental vacuum")
  func testIncrementalVacuum() async throws {
    // Set up incremental vacuum mode
    try await db.setAutoVacuum(.incremental)
    try await db.vacuum()

    // Create table and data
    try await db.exec(
      """
      CREATE TABLE test (
        id INTEGER PRIMARY KEY,
        value TEXT
      )
      """
    )

    try await db.transaction { db in
      try await db.cached {
        for i in 0..<100000 {
          try await db.exec(raw: "INSERT INTO test (value) VALUES (?)", binding: "value \(i)")
        }
      }
    }

    // Delete half the data
    try await db.exec("DELETE FROM test WHERE id % 2 = 0")

    // Perform incremental vacuum
    try await db.incrementalVacuum(pages: 10)

    // Should not throw
  }

  // MARK: - WAL Checkpoint Tests

  @Test("WAL checkpoint")
  func testWALCheckpoint() async throws {
    // Enable WAL mode
    try await db.setJournalMode(.wal)

    // Create and populate table
    try await db.exec(
      """
      CREATE TABLE test (
        id INTEGER PRIMARY KEY,
        value TEXT
      )
      """
    )

    for i in 0..<100 {
      try await db.exec(raw: "INSERT INTO test (value) VALUES (?)", binding: "value \(i)")
    }

    // Perform checkpoint
    let info = try await db.walCheckpoint(mode: .passive)
    #expect(info.logPages >= 0)
    #expect(info.checkpointedPages >= 0)
    #expect(info.checkpointedPages <= info.logPages)

    // Try different checkpoint modes
    _ = try await db.walCheckpoint(mode: .full)
    _ = try await db.walCheckpoint(mode: .restart)
    _ = try await db.walCheckpoint(mode: .truncate)
  }

  // MARK: - Schema Introspection Tests

  @Test("Table info")
  func testTableInfo() async throws {
    try await db.exec(
      """
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        age INTEGER DEFAULT 0
      )
      """
    )

    let columns = try await db.tableInfo("users")
    #expect(columns.count == 4)

    // Check id column
    let idCol = columns.first { $0.name == "id" }
    #expect(idCol != nil)
    #expect(idCol?.type.uppercased() == "INTEGER")
    #expect(idCol?.pk == 1)

    // Check name column
    let nameCol = columns.first { $0.name == "name" }
    #expect(nameCol != nil)
    #expect(nameCol?.type.uppercased() == "TEXT")
    #expect(nameCol?.notNull == true)
    #expect(nameCol?.pk == 0)

    // Check age column (has default)
    let ageCol = columns.first { $0.name == "age" }
    #expect(ageCol != nil)
    #expect(ageCol?.defaultValue == "0")
  }

  @Test("Table list")
  func testTableList() async throws {
    // Initially should be empty
    var tables = try await db.tableList()
    #expect(tables.count == 1)  // sqlite_schema table

    // Create some tables
    try await db.exec(
      """
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT
      )
      """
    )

    try await db.exec(
      """
      CREATE TABLE posts (
        id INTEGER PRIMARY KEY,
        title TEXT
      )
      """
    )

    tables = try await db.tableList()
    #expect(tables.count == 3)

    let userTable = tables.first { $0.name == "users" }
    #expect(userTable != nil)
    #expect(userTable?.type == "table")
    #expect(userTable?.ncol == 2)

    let postTable = tables.first { $0.name == "posts" }
    #expect(postTable != nil)
  }

  @Test("Index list")
  func testIndexList() async throws {
    try await db.exec(
      """
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT UNIQUE
      )
      """
    )

    // Create an index
    try await db.exec("CREATE INDEX idx_users_name ON users(name)")

    let indexes = try await db.indexList("users")

    // Should have at least 2: one for UNIQUE email, one for name
    #expect(indexes.count >= 2)

    let nameIndex = indexes.first { $0.name == "idx_users_name" }
    #expect(nameIndex != nil)
    #expect(nameIndex?.unique == false)
    #expect(nameIndex?.origin == "c")  // Created with CREATE INDEX

    let emailIndex = indexes.first { $0.name != "idx_users_name" }
    #expect(emailIndex != nil)
    #expect(emailIndex?.unique == true)
  }

  @Test("Index info")
  func testIndexInfo() async throws {
    try await db.exec(
      """
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        first_name TEXT,
        last_name TEXT,
        email TEXT
      )
      """
    )

    try await db.exec("CREATE INDEX idx_users_name ON users(last_name, first_name)")

    let columns = try await db.indexInfo("idx_users_name")
    try #require(columns.count >= 2)

    // Check last_name comes first
    #expect(columns[0].name == "last_name")
    #expect(columns[0].seqno == 0)
    #expect(columns[0].key == true)

    // Check first_name comes second
    #expect(columns[1].name == "first_name")
    #expect(columns[1].seqno == 1)
    #expect(columns[1].key == true)
  }

  @Test("Foreign key list")
  func testForeignKeyList() async throws {
    try await db.exec(
      """
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT
      )
      """
    )

    try await db.exec(
      """
      CREATE TABLE posts (
        id INTEGER PRIMARY KEY,
        user_id INTEGER NOT NULL,
        title TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE RESTRICT
      )
      """
    )

    let foreignKeys = try await db.foreignKeyList("posts")
    try #require(foreignKeys.count == 1)

    let fk = foreignKeys[0]
    #expect(fk.table == "users")
    #expect(fk.from == "user_id")
    #expect(fk.to == "id")
    #expect(fk.onDelete == "CASCADE")
    #expect(fk.onUpdate == "RESTRICT")
  }

  @Test("Foreign key list with multiple constraints")
  func testMultipleForeignKeys() async throws {
    try await db.exec(
      """
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT
      )
      """
    )

    try await db.exec(
      """
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY,
        name TEXT
      )
      """
    )

    try await db.exec(
      """
      CREATE TABLE posts (
        id INTEGER PRIMARY KEY,
        user_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        title TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
      )
      """
    )

    let foreignKeys = try await db.foreignKeyList("posts")
    #expect(foreignKeys.count == 2)

    let userFK = foreignKeys.first { $0.table == "users" }
    #expect(userFK != nil)
    #expect(userFK?.from == "user_id")
    #expect(userFK?.onDelete == "CASCADE")

    let categoryFK = foreignKeys.first { $0.table == "categories" }
    #expect(categoryFK != nil)
    #expect(categoryFK?.from == "category_id")
    #expect(categoryFK?.onDelete == "SET NULL")
  }

  // MARK: - Integration Tests

  @Test("Configure database for production use")
  func testProductionConfiguration() async throws {
    // Enable WAL mode for better concurrency
    try await db.setJournalMode(.wal)
    #expect(try await db.getJournalMode() == .wal)

    // Set synchronous to NORMAL (good for WAL)
    try await db.setSynchronous(.normal)
    #expect(try await db.getSynchronous() == .normal)

    // Increase cache size
    try await db.setCacheSize(.kibibytes(10240))  // 10MB
    #expect(try await db.getCacheSize() == .kibibytes(10240))

    // Use memory for temp tables
    try await db.setTempStore(.memory)
    #expect(try await db.getTempStore() == .memory)

    // Enable foreign keys
    try await db.setForeignKeys(true)
    #expect(try await db.getForeignKeys() == true)

    // Database should still work normally
    try await db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, value TEXT)")
    try await db.exec(raw: "INSERT INTO test (value) VALUES (?)", binding: "test")

    let count = try await db.query("SELECT COUNT(*) FROM test") { stmt, _ in
      try Int32.column(of: stmt, at: 0)
    }
    #expect(count.first == 1)
  }
}
