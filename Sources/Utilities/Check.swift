import Foundation
import SQLite3

/// Validates that a SQLite operation returns the expected result code.
///
/// This function executes a SQLite operation and verifies it returns the specified result code.
/// If the actual result differs from the expected code, it throws a `LoomError` with details
/// from the database or SQLite error string.
///
/// The following example demonstrates its usage:
///
///     try check(sqlite3_step(statement), db: db, is: SQLITE_DONE)
///
/// - Parameters:
///   - block: The SQLite operation to execute (auto-closure for lazy evaluation).
///   - db: Optional database handle for detailed error messages via `sqlite3_errmsg()`.
///         If `nil`, uses `sqlite3_errstr()` for generic error descriptions.
///   - result: The expected SQLite result code (e.g., `SQLITE_OK`, `SQLITE_DONE`).
///
/// - Throws: `LoomError` containing the actual result code and error message when the
///           operation returns a code different from the expected `result`.
@DatabaseActor
func check(
  _ block: @autoclosure () -> Int32,
  db: OpaquePointer? = nil,
  is result: Int32
) throws(LoomError) {
  let code = block()
  guard result != code else { return }
  if let db {
    throw LoomError(sqlite: code, message: String(cString: sqlite3_errmsg(db)))
  } else {
    throw LoomError(sqlite: code, message: String(cString: sqlite3_errstr(code)))
  }
}

/// Validates that a SQLite operation returns one of several acceptable result codes.
///
/// This function executes a SQLite operation and verifies it returns one of the specified
/// result codes. If the actual result is not in the set of acceptable codes, it throws a
/// `LoomError` with details from the database or SQLite error string.
///
/// The following example demonstrates its usage:
///
///     let result = try check(sqlite3_step(statement), db: db, in: SQLITE_ROW, SQLITE_DONE)
///     if result == SQLITE_ROW {
///       // Process row data
///     }
///
/// - Parameters:
///   - block: The SQLite operation to execute (auto-closure for lazy evaluation).
///   - db: Optional database handle for detailed error messages via `sqlite3_errmsg()`.
///         If `nil`, uses `sqlite3_errstr()` for generic error descriptions.
///   - results: Variadic list of acceptable SQLite result codes (e.g., `SQLITE_OK`, `SQLITE_ROW`).
///
/// - Throws: `LoomError` containing the actual result code and error message when the
///           operation returns a code not present in `results`.
///
/// - Returns: The actual result code from the SQLite operation (guaranteed to be one of
///            the acceptable codes if no error is thrown).
@DatabaseActor
func check(
  _ block: @autoclosure () -> Int32,
  db: OpaquePointer? = nil,
  in results: Int32...
) throws(LoomError) -> Int32 {
  let code = block()
  guard !results.contains(code) else { return code }
  if let db {
    throw LoomError(sqlite: code, message: String(cString: sqlite3_errmsg(db)))
  } else {
    throw LoomError(sqlite: code, message: String(cString: sqlite3_errstr(code)))
  }
}
