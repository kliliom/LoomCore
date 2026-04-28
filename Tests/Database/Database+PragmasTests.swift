import Foundation
import Testing

@testable import LoomCore

@Suite("Database Pragmas Tests")
@DatabaseActor
class DatabasePragmasTests {

  let url: URL
  let db: Database

  init() throws {
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
  func testJournalMode() throws {
    // Default should be DELETE for in-memory databases
    let defaultMode = try db.getJournalMode()
    #expect(defaultMode == .memory || defaultMode == .delete)

    // Set to WAL
    let walMode = try db.setJournalMode(.wal)
    #expect(walMode == .wal)

    // Verify it was set
    let currentMode = try db.getJournalMode()
    #expect(currentMode == .wal)

    // Try other modes
    _ = try db.setJournalMode(.memory)
    #expect(try db.getJournalMode() == .memory)

    _ = try db.setJournalMode(.persist)
    #expect(try db.getJournalMode() == .persist)
  }

  // MARK: - Synchronous Mode Tests

  @Test("Get and set synchronous mode")
  func testSynchronousMode() throws {
    // Default should be FULL
    let defaultMode = try db.getSynchronous()
    #expect(defaultMode == .full)

    // Set to NORMAL
    try db.setSynchronous(.normal)
    #expect(try db.getSynchronous() == .normal)

    // Try other modes
    try db.setSynchronous(.off)
    #expect(try db.getSynchronous() == .off)

    try db.setSynchronous(.extra)
    #expect(try db.getSynchronous() == .extra)
  }

  // MARK: - Cache Size Tests

  @Test("Get and set cache size")
  func testCacheSize() throws {
    // Get default cache size
    let defaultSize = try db.getCacheSize()
    #expect(defaultSize != .pages(0) && defaultSize != .kibibytes(0))

    // Set cache size in pages
    try db.setCacheSize(.pages(5000))
    #expect(try db.getCacheSize() == .pages(5000))

    // Set cache size in kibibytes
    try db.setCacheSize(.kibibytes(10240))  // 10MB
    #expect(try db.getCacheSize() == .kibibytes(10240))
  }

  // MARK: - Temp Store Tests

  @Test("Get and set temp store mode")
  func testTempStoreMode() throws {
    // Get default temp store
    let defaultMode = try db.getTempStore()
    #expect(defaultMode == .default || defaultMode == .file || defaultMode == .memory)

    // Set to memory
    try db.setTempStore(.memory)
    #expect(try db.getTempStore() == .memory)

    // Set to file
    try db.setTempStore(.file)
    #expect(try db.getTempStore() == .file)
  }

  // MARK: - Memory-Mapped I/O Tests

  @Test("Get and set mmap size")
  func testMmapSize() throws {
    // Get default mmap size
    let defaultSize = try db.getMmapSize()
    #expect(defaultSize >= 0)

    // Set mmap size to 256MB
    #expect(try db.setMmapSize(10 * 1024 * 1024) == 10 * 1024 * 1024)
    #expect(try db.getMmapSize() == 10 * 1024 * 1024)

    // Disable mmap
    #expect(try db.setMmapSize(0) == 0)
    #expect(try db.getMmapSize() == 0)
  }

  // MARK: - Foreign Keys Tests

  @Test("Get and set foreign keys enforcement")
  func testForeignKeys() throws {
    // Default should be disabled
    #expect(try db.getForeignKeys() == false)

    // Enable foreign keys
    try db.setForeignKeys(true)
    #expect(try db.getForeignKeys() == true)

    // Disable foreign keys
    try db.setForeignKeys(false)
    #expect(try db.getForeignKeys() == false)
  }

  @Test("Foreign keys prevent invalid inserts when enabled")
  func testForeignKeysEnforcement() throws {
    try db.setForeignKeys(true)

    // Create parent and child tables
    try db.exec(
      """
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL
      )
      """
    )

    try db.exec(
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
    try db.exec(raw: "INSERT INTO users (id, name) VALUES (?, ?)", binding: 1, "Alice")

    // This should succeed
    try db.exec(raw: "INSERT INTO posts (user_id, title) VALUES (?, ?)", binding: 1, "Post 1")

    // This should fail (user_id 999 doesn't exist)
    #expect(throws: LoomError.self) {
      try db.exec(raw: "INSERT INTO posts (user_id, title) VALUES (?, ?)", binding: 999, "Post 2")
    }
  }

  // MARK: - Auto Vacuum Tests

  @Test("Get and set auto vacuum mode")
  func testAutoVacuumMode() throws {
    // Default should be NONE
    #expect(try db.getAutoVacuum() == .none)

    // Set to incremental (requires VACUUM to take effect)
    try db.setAutoVacuum(.incremental)
    try db.vacuum()
    #expect(try db.getAutoVacuum() == .incremental)
  }

  // MARK: - Maintenance Operations Tests

  @Test("Integrity check on healthy database")
  func testIntegrityCheckHealthy() throws {
    // Create a simple table
    try db.exec(
      """
      CREATE TABLE test (
        id INTEGER PRIMARY KEY,
        value TEXT
      )
      """
    )

    try db.exec(raw: "INSERT INTO test (value) VALUES (?)", binding: "test data")

    // Should return empty array (no issues)
    let issues = try db.integrityCheck()
    #expect(issues.isEmpty)
  }

  @Test("Optimize database")
  func testOptimize() throws {
    // Create some tables and data
    try db.exec(
      """
      CREATE TABLE test (
        id INTEGER PRIMARY KEY,
        value TEXT
      )
      """
    )

    for i in 0..<100 {
      try db.exec(raw: "INSERT INTO test (value) VALUES (?)", binding: "value \(i)")
    }

    // Optimize should not throw
    try db.optimize()
  }

  @Test("Vacuum database")
  func testVacuum() throws {
    // Create table and data
    try db.exec(
      """
      CREATE TABLE test (
        id INTEGER PRIMARY KEY,
        value TEXT
      )
      """
    )

    for i in 0..<1000 {
      try db.exec(raw: "INSERT INTO test (value) VALUES (?)", binding: "value \(i)")
    }

    // Delete half the data
    try db.exec("DELETE FROM test WHERE id % 2 = 0")

    // Get database size before vacuum
    let sizeBefore = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64

    // Vacuum should reclaim space
    try db.vacuum()

    // Get database size after vacuum
    let sizeAfter = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64

    // Size should be reduced (or at least not increased)
    if let before = sizeBefore, let after = sizeAfter {
      #expect(after <= before)
    }

    // Verify data integrity after vacuum
    let count = try db.query("SELECT COUNT(*) FROM test") { stmt, _ in
      try Int32.column(of: stmt, at: 0)
    }
    #expect(count.first == 500)
  }

  @Test("Incremental vacuum")
  func testIncrementalVacuum() throws {
    // Set up incremental vacuum mode
    try db.setAutoVacuum(.incremental)
    try db.vacuum()

    // Create table and data
    try db.exec(
      """
      CREATE TABLE test (
        id INTEGER PRIMARY KEY,
        value TEXT
      )
      """
    )

    try db.transaction {
      try db.cached {
        for i in 0..<100000 {
          try db.exec(raw: "INSERT INTO test (value) VALUES (?)", binding: "value \(i)")
        }
      }
    }

    // Delete half the data
    try db.exec("DELETE FROM test WHERE id % 2 = 0")

    // Perform incremental vacuum
    try db.incrementalVacuum(pages: 10)

    // Should not throw
  }

  // MARK: - WAL Checkpoint Tests

  @Test("WAL checkpoint")
  func testWALCheckpoint() throws {
    // Enable WAL mode
    try db.setJournalMode(.wal)

    // Create and populate table
    try db.exec(
      """
      CREATE TABLE test (
        id INTEGER PRIMARY KEY,
        value TEXT
      )
      """
    )

    for i in 0..<100 {
      try db.exec(raw: "INSERT INTO test (value) VALUES (?)", binding: "value \(i)")
    }

    // Perform checkpoint
    let info = try db.walCheckpoint(mode: .passive)
    #expect(info.logPages >= 0)
    #expect(info.checkpointedPages >= 0)
    #expect(info.checkpointedPages <= info.logPages)

    // Try different checkpoint modes
    _ = try db.walCheckpoint(mode: .full)
    _ = try db.walCheckpoint(mode: .restart)
    _ = try db.walCheckpoint(mode: .truncate)
  }

  // MARK: - Schema Introspection Tests

  @Test("Table info")
  func testTableInfo() throws {
    try db.exec(
      """
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        age INTEGER DEFAULT 0
      )
      """
    )

    let columns = try db.tableInfo("users")
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
  func testTableList() throws {
    // Initially should be empty
    var tables = try db.tableList()
    #expect(tables.count == 1)  // sqlite_schema table

    // Create some tables
    try db.exec(
      """
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT
      )
      """
    )

    try db.exec(
      """
      CREATE TABLE posts (
        id INTEGER PRIMARY KEY,
        title TEXT
      )
      """
    )

    tables = try db.tableList()
    #expect(tables.count == 3)

    let userTable = tables.first { $0.name == "users" }
    #expect(userTable != nil)
    #expect(userTable?.type == "table")
    #expect(userTable?.ncol == 2)

    let postTable = tables.first { $0.name == "posts" }
    #expect(postTable != nil)
  }

  @Test("Index list")
  func testIndexList() throws {
    try db.exec(
      """
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT UNIQUE
      )
      """
    )

    // Create an index
    try db.exec("CREATE INDEX idx_users_name ON users(name)")

    let indexes = try db.indexList("users")

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
  func testIndexInfo() throws {
    try db.exec(
      """
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        first_name TEXT,
        last_name TEXT,
        email TEXT
      )
      """
    )

    try db.exec("CREATE INDEX idx_users_name ON users(last_name, first_name)")

    let columns = try db.indexInfo("idx_users_name")
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
  func testForeignKeyList() throws {
    try db.exec(
      """
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT
      )
      """
    )

    try db.exec(
      """
      CREATE TABLE posts (
        id INTEGER PRIMARY KEY,
        user_id INTEGER NOT NULL,
        title TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE RESTRICT
      )
      """
    )

    let foreignKeys = try db.foreignKeyList("posts")
    try #require(foreignKeys.count == 1)

    let fk = foreignKeys[0]
    #expect(fk.table == "users")
    #expect(fk.from == "user_id")
    #expect(fk.to == "id")
    #expect(fk.onDelete == "CASCADE")
    #expect(fk.onUpdate == "RESTRICT")
  }

  @Test("Foreign key list with multiple constraints")
  func testMultipleForeignKeys() throws {
    try db.exec(
      """
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT
      )
      """
    )

    try db.exec(
      """
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY,
        name TEXT
      )
      """
    )

    try db.exec(
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

    let foreignKeys = try db.foreignKeyList("posts")
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
  func testProductionConfiguration() throws {
    // Enable WAL mode for better concurrency
    try db.setJournalMode(.wal)
    #expect(try db.getJournalMode() == .wal)

    // Set synchronous to NORMAL (good for WAL)
    try db.setSynchronous(.normal)
    #expect(try db.getSynchronous() == .normal)

    // Increase cache size
    try db.setCacheSize(.kibibytes(10240))  // 10MB
    #expect(try db.getCacheSize() == .kibibytes(10240))

    // Use memory for temp tables
    try db.setTempStore(.memory)
    #expect(try db.getTempStore() == .memory)

    // Enable foreign keys
    try db.setForeignKeys(true)
    #expect(try db.getForeignKeys() == true)

    // Database should still work normally
    try db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, value TEXT)")
    try db.exec(raw: "INSERT INTO test (value) VALUES (?)", binding: "test")

    let count = try db.query("SELECT COUNT(*) FROM test") { stmt, _ in
      try Int32.column(of: stmt, at: 0)
    }
    #expect(count.first == 1)
  }
}
