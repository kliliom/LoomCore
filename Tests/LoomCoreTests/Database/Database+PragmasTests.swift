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
    let defaultMode = try await db.getJournalMode()
    #expect(defaultMode == .memory || defaultMode == .delete)

    let walMode = try await db.setJournalMode(.wal)
    #expect(walMode == .wal)

    let currentMode = try await db.getJournalMode()
    #expect(currentMode == .wal)

    _ = try await db.setJournalMode(.memory)
    #expect(try await db.getJournalMode() == .memory)

    _ = try await db.setJournalMode(.persist)
    #expect(try await db.getJournalMode() == .persist)
  }

  // MARK: - Synchronous Mode Tests

  @Test("Get and set synchronous mode")
  func testSynchronousMode() async throws {
    let defaultMode = try await db.getSynchronous()
    #expect(defaultMode == .full)

    try await db.setSynchronous(.normal)
    #expect(try await db.getSynchronous() == .normal)

    try await db.setSynchronous(.off)
    #expect(try await db.getSynchronous() == .off)

    try await db.setSynchronous(.extra)
    #expect(try await db.getSynchronous() == .extra)
  }

  // MARK: - Cache Size Tests

  @Test("Get and set cache size")
  func testCacheSize() async throws {
    let defaultSize = try await db.getCacheSize()
    #expect(defaultSize != .pages(0) && defaultSize != .kibibytes(0))

    try await db.setCacheSize(.pages(5000))
    #expect(try await db.getCacheSize() == .pages(5000))

    try await db.setCacheSize(.kibibytes(10240))  // 10MB
    #expect(try await db.getCacheSize() == .kibibytes(10240))
  }

  // MARK: - Temp Store Tests

  @Test("Get and set temp store mode")
  func testTempStoreMode() async throws {
    let defaultMode = try await db.getTempStore()
    #expect(defaultMode == .default || defaultMode == .file || defaultMode == .memory)

    try await db.setTempStore(.memory)
    #expect(try await db.getTempStore() == .memory)

    try await db.setTempStore(.file)
    #expect(try await db.getTempStore() == .file)
  }

  // MARK: - Memory-Mapped I/O Tests

  @Test("Get and set mmap size")
  func testMmapSize() async throws {
    let defaultSize = try await db.getMmapSize()
    #expect(defaultSize >= 0)

    #expect(try await db.setMmapSize(10 * 1024 * 1024) == 10 * 1024 * 1024)
    #expect(try await db.getMmapSize() == 10 * 1024 * 1024)

    #expect(try await db.setMmapSize(0) == 0)
    #expect(try await db.getMmapSize() == 0)
  }

  // MARK: - Foreign Keys Tests

  @Test("Get and set foreign keys enforcement")
  func testForeignKeys() async throws {
    #expect(try await db.getForeignKeys() == false)

    try await db.setForeignKeys(true)
    #expect(try await db.getForeignKeys() == true)

    try await db.setForeignKeys(false)
    #expect(try await db.getForeignKeys() == false)
  }

  @Test("Foreign keys prevent invalid inserts when enabled")
  func testForeignKeysEnforcement() async throws {
    try await db.setForeignKeys(true)

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

    try await db.exec(raw: "INSERT INTO users (id, name) VALUES (?, ?)", binding: 1, "Alice")

    try await db.exec(raw: "INSERT INTO posts (user_id, title) VALUES (?, ?)", binding: 1, "Post 1")

    await #expect(throws: LoomError.self) {
      try await db.exec(raw: "INSERT INTO posts (user_id, title) VALUES (?, ?)", binding: 999, "Post 2")
    }
  }

  // MARK: - Auto Vacuum Tests

  @Test("Get and set auto vacuum mode")
  func testAutoVacuumMode() async throws {
    #expect(try await db.getAutoVacuum() == .none)

    // A switch to incremental takes effect only after VACUUM.
    try await db.setAutoVacuum(.incremental)
    try await db.vacuum()
    #expect(try await db.getAutoVacuum() == .incremental)
  }

  // MARK: - Maintenance Operations Tests

  @Test("Integrity check on healthy database")
  func testIntegrityCheckHealthy() async throws {
    try await db.exec(
      """
      CREATE TABLE test (
        id INTEGER PRIMARY KEY,
        value TEXT
      )
      """
    )

    try await db.exec(raw: "INSERT INTO test (value) VALUES (?)", binding: "test data")

    let issues = try await db.integrityCheck()
    #expect(issues.isEmpty)
  }

  @Test("Optimize database")
  func testOptimize() async throws {
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

    try await db.optimize()
  }

  @Test("Vacuum database")
  func testVacuum() async throws {
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

    try await db.exec("DELETE FROM test WHERE id % 2 = 0")

    let sizeBefore = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64

    try await db.vacuum()

    let sizeAfter = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64

    if let before = sizeBefore, let after = sizeAfter {
      #expect(after <= before)
    }

    let count = try await db.query("SELECT COUNT(*) FROM test") { stmt, _ in
      try Int32.column(of: stmt, at: 0)
    }
    #expect(count.first == 500)
  }

  @Test("Incremental vacuum")
  func testIncrementalVacuum() async throws {
    try await db.setAutoVacuum(.incremental)
    try await db.vacuum()

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

    try await db.exec("DELETE FROM test WHERE id % 2 = 0")

    try await db.incrementalVacuum(pages: 10)
  }

  // MARK: - WAL Checkpoint Tests

  @Test("WAL checkpoint")
  func testWALCheckpoint() async throws {
    try await db.setJournalMode(.wal)

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

    let info = try await db.walCheckpoint(mode: .passive)
    #expect(info.logPages >= 0)
    #expect(info.checkpointedPages >= 0)
    #expect(info.checkpointedPages <= info.logPages)

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

    let idCol = columns.first { $0.name == "id" }
    #expect(idCol != nil)
    #expect(idCol?.type.uppercased() == "INTEGER")
    #expect(idCol?.pk == 1)

    let nameCol = columns.first { $0.name == "name" }
    #expect(nameCol != nil)
    #expect(nameCol?.type.uppercased() == "TEXT")
    #expect(nameCol?.notNull == true)
    #expect(nameCol?.pk == 0)

    let ageCol = columns.first { $0.name == "age" }
    #expect(ageCol != nil)
    #expect(ageCol?.defaultValue == "0")
  }

  @Test("Table list")
  func testTableList() async throws {
    var tables = try await db.tableList()
    #expect(tables.count == 1)  // sqlite_schema table

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

    #expect(columns[0].name == "last_name")
    #expect(columns[0].seqno == 0)
    #expect(columns[0].key == true)

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

  // MARK: - Identifier Safety Tests

  @Test("Introspection works on identifiers that need quoting")
  func testIntrospectsQuotedIdentifiers() async throws {
    try await db.exec(
      """
      CREATE TABLE "my table" (
        id INTEGER PRIMARY KEY,
        "order" TEXT
      )
      """
    )
    try await db.exec(
      """
      CREATE TABLE "order" (
        id INTEGER PRIMARY KEY,
        "my table_id" INTEGER REFERENCES "my table"(id)
      )
      """
    )
    try await db.exec(#"CREATE INDEX "idx my index" ON "my table" ("order")"#)

    // Names containing spaces or reserved words prepare only because they are bound;
    // spliced into the PRAGMA text they would be a syntax error.
    let columns = try await db.tableInfo("my table")
    #expect(columns.map(\.name) == ["id", "order"])

    let reserved = try await db.tableInfo("order")
    #expect(reserved.map(\.name) == ["id", "my table_id"])

    let indexes = try await db.indexList("my table").map(\.name)
    #expect(indexes.contains("idx my index"))

    let indexColumns = try await db.indexInfo("idx my index")
    #expect(indexColumns.first?.name == "order")

    let foreignKeys = try await db.foreignKeyList("order")
    try #require(foreignKeys.count == 1)
    #expect(foreignKeys[0].table == "my table")
    #expect(foreignKeys[0].from == "my table_id")
  }

  @Test("Schema name is bound, never parsed as SQL")
  func testSchemaNameIsBound() async throws {
    // Bound, a schema name containing a space simply matches nothing; spliced after the
    // PRAGMA keyword it would be a syntax error.
    let tables = try await db.tableList(schema: "not a schema")
    #expect(tables.isEmpty)
  }

  @Test("Schema name cannot execute a different pragma")
  func testSchemaNameCannotExecutePragma() async throws {
    try await db.setSynchronous(.full)
    #expect(try await db.getSynchronous() == .full)

    let ignoreCheckConstraints = {
      try await self.db.query("PRAGMA ignore_check_constraints") { stmt, _ in
        try Int32.column(of: stmt, at: 0)
      }.first ?? 0
    }
    #expect(try await ignoreCheckConstraints() == 0)

    // Spliced into the PRAGMA text, these payloads would land in the pragma-name position,
    // replacing the intended pragma outright and flipping connection state.
    _ = try? await db.tableList(schema: "synchronous = OFF --")
    _ = try? await db.tableList(schema: "ignore_check_constraints = ON --")
    _ = try? await db.walCheckpoint(database: "synchronous = OFF --")

    #expect(try await db.getSynchronous() == .full)
    #expect(try await ignoreCheckConstraints() == 0)
  }

  @Test("WAL checkpoint rejects an unknown database name")
  func testWALCheckpointUnknownDatabase() async throws {
    try await db.setJournalMode(.wal)

    await #expect(throws: LoomError.self) {
      _ = try await self.db.walCheckpoint(database: "no such database")
    }
  }

  @Test("WAL checkpoint resolves database names case-insensitively")
  func testWALCheckpointCaseInsensitiveDatabase() async throws {
    try await db.setJournalMode(.wal)
    try await db.exec("CREATE TABLE t (x INTEGER)")
    try await db.exec("INSERT INTO t VALUES (1)")

    let info = try await db.walCheckpoint(mode: .truncate, database: "MAIN")
    #expect(info.busy == false)
    #expect(info.checkpointedPages >= 0)
  }

  @Test("WAL checkpoint of every attached database via nil or empty name")
  func testWALCheckpointAllDatabases() async throws {
    // nil and "" opt in to the sqlite3_wal_checkpoint_v2 "all databases" form.
    try await db.setJournalMode(.wal)
    try await db.exec("CREATE TABLE t (x INTEGER)")
    try await db.exec("INSERT INTO t VALUES (1)")

    let nilInfo = try await db.walCheckpoint(mode: .passive, database: nil)
    #expect(nilInfo.busy == false)

    let emptyInfo = try await db.walCheckpoint(mode: .passive, database: "")
    #expect(emptyInfo.busy == false)
  }

  @Test("Table list resolves schema names case-insensitively")
  func testTableListCaseInsensitiveSchema() async throws {
    // SQLite resolves schema names case-insensitively everywhere (`SELECT * FROM MAIN.t`
    // works); a BINARY comparison against pragma_table_list's output would return [].
    try await db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY)")

    let upper = try await db.tableList(schema: "MAIN").map(\.name)
    #expect(upper.contains("users"))

    try await db.exec("ATTACH ':memory:' AS Aux")
    try await db.exec("CREATE TABLE Aux.extras (id INTEGER PRIMARY KEY)")

    let attached = try await db.tableList(schema: "aux").map(\.name)
    #expect(attached.contains("extras"))
  }

  // MARK: - Integration Tests

  @Test("Configure database for production use")
  func testProductionConfiguration() async throws {
    try await db.setJournalMode(.wal)
    #expect(try await db.getJournalMode() == .wal)

    try await db.setSynchronous(.normal)
    #expect(try await db.getSynchronous() == .normal)

    try await db.setCacheSize(.kibibytes(10240))  // 10MB
    #expect(try await db.getCacheSize() == .kibibytes(10240))

    try await db.setTempStore(.memory)
    #expect(try await db.getTempStore() == .memory)

    try await db.setForeignKeys(true)
    #expect(try await db.getForeignKeys() == true)

    try await db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, value TEXT)")
    try await db.exec(raw: "INSERT INTO test (value) VALUES (?)", binding: "test")

    let count = try await db.query("SELECT COUNT(*) FROM test") { stmt, _ in
      try Int32.column(of: stmt, at: 0)
    }
    #expect(count.first == 1)
  }

  @Test("Busy timeout defaults to zero and round-trips")
  func testBusyTimeout() async throws {
    let db = try Database.openInMemory()

    #expect(try await db.getBusyTimeout() == 0)

    // PRAGMA busy_timeout = N returns a row, so the setter must run as a query;
    // the returned value pins that it applied.
    #expect(try await db.setBusyTimeout(milliseconds: 250) == 250)
    #expect(try await db.getBusyTimeout() == 250)

    #expect(try await db.setBusyTimeout(milliseconds: 0) == 0)
    #expect(try await db.getBusyTimeout() == 0)
  }
}
