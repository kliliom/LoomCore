/// Database methods for low-level SQLite C API access.

extension Database {
  /// Exposes the underlying `sqlite3*` handle for direct SQLite C API calls.
  ///
  /// Use this when the high-level API doesn't cover what you need: registering custom
  /// functions, loading extensions, calling pragmas with C-only callbacks, or reading
  /// connection-level state like `sqlite3_changes` or `sqlite3_last_insert_rowid`.
  ///
  /// ```swift
  /// import SQLite3
  ///
  /// let changes = try db.directAccess { ptr in
  ///   Int(sqlite3_changes(ptr))
  /// }
  /// ```
  ///
  /// The handle is only valid for the duration of `block`. Storing it, escaping it into
  /// another task, or using it after the closure returns is undefined behavior.
  ///
  /// - Parameter block: Receives the live `sqlite3*` pointer. Must not retain or escape it.
  public func directAccess<T>(_ block: @DatabaseActor (_ ptr: OpaquePointer) throws -> T) throws -> T {
    try block(handle.ptr)
  }
}
