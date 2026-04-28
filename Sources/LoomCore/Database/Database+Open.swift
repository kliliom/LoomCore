import Foundation
import SQLite3

extension Database {
  /// Opens a connection to an in-memory database.
  ///
  /// In-memory databases are not persisted to disk and exist only for the lifetime
  /// of the connection. They are ideal for temporary data, testing, or caching scenarios.
  ///
  /// Each call to this method creates a completely independent database. Data is not
  /// shared between different in-memory database instances.
  ///
  /// The following example demonstrates its usage:
  ///
  ///     let db = try await Database.openInMemory()
  ///
  /// - Returns: A new ``Database`` instance backed by an in-memory SQLite database.
  /// - Throws: `LoomError` if the SQLite connection cannot be established.
  public static func openInMemory() throws -> Database {
    var ptr: OpaquePointer?
    try check(sqlite3_open(":memory:", &ptr), is: SQLITE_OK)
    guard let ptr else {
      throw LoomError.core(.unexpectedState, message: "sqlite3_open() did not return a database pointer.")
    }
    return Database(handle: DatabaseHandle(ptr: ptr))
  }

  /// Opens a connection to a persistent on-disk database.
  ///
  /// If the database file doesn't exist at the specified path, SQLite will create it
  /// automatically. The file will persist across app launches until explicitly deleted.
  ///
  /// The following example demonstrates opening a database from the documents directory:
  ///
  ///     // Get the URL of the documents directory.
  ///     let documentsURL = FileManager.default
  ///         .urls(for: .documentDirectory, in: .userDomainMask)
  ///         .first!
  ///
  ///     // Append the database file name to the documents URL.
  ///     let databaseURL = documentsURL.appending(path: "db.sqlite")
  ///
  ///     // Open the database.
  ///     let db = try await Database.open(url: databaseURL)
  ///
  /// - Parameter url: File URL of the database to open. Must use the `file:` scheme.
  /// - Returns: A new ``Database`` instance connected to the database at the given URL.
  /// - Throws: `LoomError` if the URL is invalid or if the SQLite connection cannot be established.
  public static func open(url: URL) throws -> Database {
    guard url.isFileURL else {
      throw LoomError.core(.invalidDatabasePath, message: "Database URL must use the file: scheme.")
    }
    var ptr: OpaquePointer?
    let path: String = url.path(percentEncoded: false)
    try check(sqlite3_open(path, &ptr), is: SQLITE_OK)
    guard let ptr else {
      throw LoomError.core(.unexpectedState, message: "sqlite3_open() did not return a database pointer.")
    }
    return Database(handle: DatabaseHandle(ptr: ptr))
  }
}
