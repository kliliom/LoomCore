import Foundation
import SQLite3

extension Database {
  /// Opens a connection to an in-memory database.
  ///
  /// In-memory databases are not persisted to disk and exist only for the lifetime
  /// of the connection. Each call creates an independent database — data is not
  /// shared between instances. Suited to tests, ephemeral caches, and scratch
  /// computation.
  ///
  /// ```swift
  /// let db = try await Database.openInMemory()
  /// try await db.exec("CREATE TABLE event (id INTEGER PRIMARY KEY, payload TEXT)")
  /// try await db.exec(raw: "INSERT INTO event (payload) VALUES (?)", binding: "login")
  /// ```
  ///
  /// - Parameter statementCacheCapacity: Maximum number of prepared statements retained by
  ///   ``cached(_:)`` blocks before the least-recently-used one is evicted. Must be positive.
  /// - Throws: ``LoomError`` if the SQLite connection cannot be established.
  public static func openInMemory(statementCacheCapacity: Int = 128) throws -> Database {
    let ptr = try openConnection(":memory:")
    return Database(handle: DatabaseHandle(ptr: ptr, statementCacheCapacity: statementCacheCapacity))
  }

  /// Opens a connection to a persistent on-disk database.
  ///
  /// SQLite creates the file at `url` if it does not already exist. The file
  /// persists across launches until explicitly deleted.
  ///
  /// ```swift
  /// let documentsURL = FileManager.default
  ///     .urls(for: .documentDirectory, in: .userDomainMask)
  ///     .first!
  /// let databaseURL = documentsURL.appending(path: "app.sqlite")
  ///
  /// let db = try await Database.open(url: databaseURL)
  /// try await db.exec("""
  ///     CREATE TABLE IF NOT EXISTS account (
  ///         id INTEGER PRIMARY KEY,
  ///         email TEXT NOT NULL UNIQUE
  ///     )
  ///     """)
  /// ```
  ///
  /// - Parameters:
  ///   - url: File URL pointing at the database. Must use the `file:` scheme.
  ///   - statementCacheCapacity: Maximum number of prepared statements retained by
  ///     ``cached(_:)`` blocks before the least-recently-used one is evicted. Must be positive.
  /// - Throws: ``LoomError`` if `url` is not a file URL or the SQLite connection cannot be established.
  public static func open(url: URL, statementCacheCapacity: Int = 128) throws -> Database {
    guard url.isFileURL else {
      throw LoomError.core(.invalidDatabasePath, message: "Database URL must use the file: scheme.")
    }
    let ptr = try openConnection(url.path(percentEncoded: false))
    return Database(handle: DatabaseHandle(ptr: ptr, statementCacheCapacity: statementCacheCapacity))
  }

  /// Opens a raw SQLite connection, closing the handle SQLite allocates even when the open fails.
  private static func openConnection(_ filename: String) throws -> OpaquePointer {
    var ptr: OpaquePointer?
    let code = sqlite3_open(filename, &ptr)
    guard code == SQLITE_OK else {
      let message = ptr.map { String(cString: sqlite3_errmsg($0)) } ?? String(cString: sqlite3_errstr(code))
      sqlite3_close(ptr)
      throw LoomError.sqlite(code, message: message)
    }
    guard let ptr else {
      throw LoomError.core(.unexpectedState, message: "sqlite3_open() did not return a database pointer.")
    }
    return ptr
  }
}
