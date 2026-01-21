/// Database methods for low-level SQLite C API access.
///
/// This file provides direct access to the underlying SQLite database handle for advanced
/// use cases that require calling SQLite C functions directly.

extension Database {
  /// Provides direct access to the underlying SQLite database handle.
  ///
  /// This method gives you access to the raw `sqlite3*` pointer, allowing you to call
  /// SQLite C API functions directly. This is useful for advanced scenarios not covered
  /// by the higher-level database API.
  ///
  /// ## When to Use
  ///
  /// Use direct access when you need to:
  /// - Call SQLite functions not wrapped by the library
  /// - Use SQLite extensions or custom functions
  /// - Access advanced SQLite features (window functions, FTS, etc.)
  /// - Integrate with third-party SQLite libraries
  /// - Debug or profile SQLite operations
  ///
  /// ## Example
  ///
  /// ```swift
  /// import SQLite3
  ///
  /// // Get the last inserted row ID using the C API
  /// let lastRowId = db.directAccess { dbPtr in
  ///   sqlite3_last_insert_rowid(dbPtr)
  /// }
  ///
  /// // Register a custom SQLite function
  /// db.directAccess { dbPtr in
  ///   sqlite3_create_function_v2(
  ///     dbPtr,
  ///     "my_custom_function",
  ///     1, // number of arguments
  ///     SQLITE_UTF8,
  ///     nil,
  ///     myFunctionImpl,
  ///     nil,
  ///     nil,
  ///     nil
  ///   )
  /// }
  /// ```
  ///
  /// ## Safety Considerations
  ///
  /// **Critical**: The database handle is only valid within the `block` closure. Do not:
  /// - Store the pointer for use outside the closure
  /// - Pass the pointer to asynchronous operations
  /// - Use the pointer after the closure returns
  ///
  /// Doing so will result in undefined behavior, crashes, or data corruption.
  ///
  /// ## Thread Safety
  ///
  /// The block executes on the database actor, ensuring thread-safe access to the handle.
  /// All SQLite operations using the handle are serialized with other database operations.
  ///
  /// ## Error Handling
  ///
  /// When calling SQLite C functions directly, you're responsible for:
  /// - Checking error codes returned by SQLite functions
  /// - Converting SQLite errors to Swift errors if needed
  /// - Cleaning up resources (statements, blobs, etc.)
  ///
  /// ```swift
  /// try db.directAccess { dbPtr in
  ///   let result = sqlite3_exec(dbPtr, "INVALID SQL", nil, nil, nil)
  ///   if result != SQLITE_OK {
  ///     let message = String(cString: sqlite3_errmsg(dbPtr))
  ///     throw DatabaseError(message: message)
  ///   }
  /// }
  /// ```
  ///
  /// ## Prefer High-Level API
  ///
  /// In most cases, you should use the higher-level database methods (`exec`, `query`, etc.)
  /// rather than direct access. Use this method only when the high-level API doesn't provide
  /// the functionality you need.
  ///
  /// - Parameter block: A closure that receives the SQLite database handle and can perform
  ///                    operations using the SQLite C API. The handle is only valid within
  ///                    this closure.
  /// - Returns: The result of the `block` closure.
  /// - Throws: Any error thrown by the `block` closure.
  public func directAccess<T>(_ block: @DatabaseActor (_ ptr: OpaquePointer) throws -> T) rethrows -> T {
    try block(db.ptr)
  }
}
