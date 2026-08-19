import Foundation
import LoomCore
import Testing

@Suite("Database Exec Tests")
@DatabaseActor
struct DatabaseExecTests {

  @Test("Exec with sql string and binder")
  func testExecWithSQLAndBinder() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    try await db.exec(
      raw: "INSERT INTO users (name, age) VALUES (?, ?)",
      binder: { stmt in
        try "Alice".bind(to: stmt, at: 1)
        try 25.bind(to: stmt, at: 2)
      }
    )

    let result = try await db.query("SELECT name, age FROM users") { stmt, _ in
      let name = try String.column(of: stmt, at: 0)
      let age = try Int.column(of: stmt, at: 1)
      return (name, age)
    }

    #expect(result.count == 1)
    #expect(result.first?.0 == "Alice")
    #expect(result.first?.1 == 25)
  }

  @Test("Exec with sql string")
  func testExecWithSQLString() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    try await db.exec(raw: "INSERT INTO users (name, age) VALUES ('Alice', 25)")

    let result = try await db.query("SELECT name, age FROM users") { stmt, _ in
      let name = try String.column(of: stmt, at: 0)
      let age = try Int.column(of: stmt, at: 1)
      return (name, age)
    }

    #expect(result.count == 1)
    #expect(result.first?.0 == "Alice")
    #expect(result.first?.1 == 25)
  }

  @Test("Exec with sql string and managed binder")
  func testExecWithSQLAndManagedBinder() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    try await db.exec(
      raw: "INSERT INTO users (name, age) VALUES (?, ?)",
      binder: { stmt, index in
        try "Alice".bind(to: stmt, at: &index)
        try 25.bind(to: stmt, at: &index)
      }
    )

    let result = try await db.query("SELECT name, age FROM users") { stmt, _ in
      let name = try String.column(of: stmt, at: 0)
      let age = try Int.column(of: stmt, at: 1)
      return (name, age)
    }

    #expect(result.count == 1)
    #expect(result.first?.0 == "Alice")
    #expect(result.first?.1 == 25)
  }

  @Test("Exec with sql string and binding")
  func testExecWithSQLAndBinding() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    try await db.exec(
      raw: "INSERT INTO users (name, age) VALUES (?, ?)",
      binding: "Alice",
      25
    )

    let result = try await db.query("SELECT name, age FROM users") { stmt, _ in
      let name = try String.column(of: stmt, at: 0)
      let age = try Int.column(of: stmt, at: 1)
      return (name, age)
    }

    #expect(result.count == 1)
    #expect(result.first?.0 == "Alice")
    #expect(result.first?.1 == 25)
  }

  @Test("Exec with SQLStatement")
  func testExecWithSQLStatement() async throws {
    let db = try Database.openInMemory()

    try await db.exec("CREATE TABLE users (name TEXT, age INTEGER)")

    try await db.exec("INSERT INTO users (name, age) VALUES (\("Alice"), \(25))")

    let result = try await db.query("SELECT name, age FROM users") { stmt, _ in
      let name = try String.column(of: stmt, at: 0)
      let age = try Int.column(of: stmt, at: 1)
      return (name, age)
    }

    #expect(result.count == 1)
    #expect(result.first?.0 == "Alice")
    #expect(result.first?.1 == 25)
  }

  // MARK: - Multi-Statement Scripts

  @Test("Exec script applies every statement in order")
  func testExecScriptAppliesAllStatements() async throws {
    let db = try Database.openInMemory()

    try await db.execScript(
      """
      CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);
      CREATE UNIQUE INDEX idx_users_name ON users (name);
      INSERT INTO users (name) VALUES ('Alice');
      INSERT INTO users (name) VALUES ('Bob');
      """
    )

    let names = try await db.query("SELECT name FROM users ORDER BY id") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }
    #expect(names == ["Alice", "Bob"])

    let indexes = try await db.indexList("users").map(\.name)
    #expect(indexes.contains("idx_users_name"))
  }

  @Test("Exec script tolerates comments and blank statements")
  func testExecScriptWithComments() async throws {
    let db = try Database.openInMemory()

    try await db.execScript(
      """
      -- schema v1
      CREATE TABLE t (x INTEGER);  /* inline */
      ;
      INSERT INTO t VALUES (1);
      -- trailing comment only
      """
    )

    let count = try await db.query("SELECT COUNT(*) FROM t") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(count.first == 1)
  }

  @Test("Exec script with only comments is a no-op")
  func testExecScriptCommentsOnly() async throws {
    let db = try Database.openInMemory()

    try await db.execScript("-- nothing here\n/* nor here */\n  ;  ")
  }

  @Test("Exec script drains rows produced by a statement")
  func testExecScriptDrainsRows() async throws {
    let db = try Database.openInMemory()

    try await db.execScript(
      """
      CREATE TABLE t (x INTEGER);
      INSERT INTO t VALUES (1), (2), (3);
      SELECT x FROM t;
      INSERT INTO t VALUES (4);
      """
    )

    let count = try await db.query("SELECT COUNT(*) FROM t") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(count.first == 4)
  }

  @Test("Exec script failure leaves earlier statements applied")
  func testExecScriptPartialApplication() async throws {
    let db = try Database.openInMemory()

    await #expect(throws: LoomError.self) {
      try await db.execScript(
        """
        CREATE TABLE ok (x INTEGER);
        THIS IS NOT SQL;
        CREATE TABLE never (x INTEGER);
        """
      )
    }

    let tables = try await db.tableList().map(\.name)
    #expect(tables.contains("ok"))
    #expect(!tables.contains("never"))
  }

  @Test("Exec script wrapped in a transaction is all-or-nothing")
  func testExecScriptInTransactionRollsBack() async throws {
    let db = try Database.openInMemory()

    await #expect(throws: LoomError.self) {
      try await db.transaction { db in
        try await db.execScript(
          """
          CREATE TABLE ok (x INTEGER);
          THIS IS NOT SQL;
          """
        )
      }
    }

    let tables = try await db.tableList().map(\.name)
    #expect(!tables.contains("ok"))
  }

  // MARK: - Script Transaction Safety

  @Test("Balanced BEGIN…COMMIT script applies atomically")
  func testExecScriptBalancedTransaction() async throws {
    let db = try Database.openInMemory()

    // The shape `sqlite3 .dump` emits: the script manages its own transaction and
    // closes it before returning.
    try await db.execScript(
      """
      BEGIN TRANSACTION;
      CREATE TABLE t (x INTEGER);
      INSERT INTO t VALUES (1);
      INSERT INTO t VALUES (2);
      COMMIT;
      """
    )

    let count = try await db.query("SELECT COUNT(*) FROM t") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(count.first == 2)
  }

  @Test("Script failure after BEGIN rolls back and restores autocommit")
  func testExecScriptFailureAfterBeginRollsBack() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE t (x INTEGER)")

    // A failure after the script's own BEGIN must not leave the physical transaction
    // open behind the gate — writes would land in it with nothing left to commit them.
    await #expect(throws: LoomError.self) {
      try await db.execScript(
        """
        BEGIN;
        INSERT INTO t VALUES (1);
        THIS IS NOT SQL;
        """
      )
    }

    let orphaned = try await db.query("SELECT COUNT(*) FROM t") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(orphaned.first == 0)

    // The transaction machinery still works: no phantom open transaction remains.
    try await db.transaction { db in
      try await db.exec("INSERT INTO t VALUES (2)")
    }
    let committed = try await db.query("SELECT COUNT(*) FROM t") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(committed.first == 1)
  }

  @Test("Script that leaves a transaction open is rolled back and throws")
  func testExecScriptOpenTransactionRejected() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE t (x INTEGER)")

    do {
      try await db.execScript("BEGIN; INSERT INTO t VALUES (1);")
      Issue.record("Expected an invalidScript error")
    } catch let error as LoomError {
      #expect(error.core == .invalidScript)
    }

    let count = try await db.query("SELECT COUNT(*) FROM t") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(count.first == 0)

    try await db.transaction { db in
      try await db.exec("INSERT INTO t VALUES (2)")
    }
  }

  @Test("Script COMMIT inside transaction() is rejected")
  func testExecScriptCommitInsideTransactionRejected() async throws {
    let db = try Database.openInMemory()
    try await db.exec("CREATE TABLE t (x INTEGER)")

    // The COMMIT ends the transaction the machinery owns; the script throws at that
    // statement, before anything after it can run outside the transaction. The failed
    // machinery rollback then closes the handle (documented behavior).
    do {
      try await db.transaction { db in
        try await db.exec("INSERT INTO t VALUES (1)")
        try await db.execScript("COMMIT; INSERT INTO t VALUES (2);")
      }
      Issue.record("Expected an invalidScript error")
    } catch let error as LoomError {
      #expect(error.core == .invalidScript)
    }
  }

  @Test("Script statement with a parameter placeholder is rejected")
  func testExecScriptRejectsPlaceholders() async throws {
    let db = try Database.openInMemory()

    // An unbound `?` would silently evaluate as NULL; the script must refuse it
    // before stepping the statement.
    do {
      try await db.execScript(
        """
        CREATE TABLE t (x INTEGER);
        INSERT INTO t VALUES (?);
        """
      )
      Issue.record("Expected an invalidScript error")
    } catch let error as LoomError {
      #expect(error.core == .invalidScript)
    }

    let count = try await db.query("SELECT COUNT(*) FROM t") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }
    #expect(count.first == 0)
  }

  @Test("Script containing an embedded NUL byte is rejected outright")
  func testExecScriptRejectsEmbeddedNUL() async throws {
    let db = try Database.openInMemory()

    // C-string traversal would silently stop at the NUL, half-applying the script.
    do {
      try await db.execScript("CREATE TABLE a (x INTEGER);\0CREATE TABLE b (x INTEGER);")
      Issue.record("Expected an invalidScript error")
    } catch let error as LoomError {
      #expect(error.core == .invalidScript)
    }

    let tables = try await db.tableList().map(\.name)
    #expect(!tables.contains("a"))
    #expect(!tables.contains("b"))
  }
}
