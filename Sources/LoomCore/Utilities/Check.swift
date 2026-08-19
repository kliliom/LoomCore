import Foundation
import SQLite3

/// Validates that a SQLite call returns the expected result code.
///
/// Throws `LoomError` when the call returns anything other than `result`. When `db` is
/// provided, the error message is read from `sqlite3_errmsg()` for context-specific
/// detail; otherwise it falls back to `sqlite3_errstr()`.
///
/// ```swift
/// // doc-check: skip
/// try check(sqlite3_step(statement), db: db, is: SQLITE_DONE)
/// ```
@DatabaseActor
func check(
  _ block: @autoclosure () -> Int32,
  db: OpaquePointer? = nil,
  is result: Int32
) throws {
  let code = block()
  guard result != code else { return }
  if let db {
    throw LoomError.sqlite(code, message: String(cString: sqlite3_errmsg(db)))
  } else {
    throw LoomError.sqlite(code, message: String(cString: sqlite3_errstr(code)))
  }
}

/// Validates that a SQLite call returns one of several acceptable result codes.
///
/// Throws `LoomError` when the returned code is not in `results`. When `db` is provided,
/// the error message is read from `sqlite3_errmsg()`; otherwise it falls back to
/// `sqlite3_errstr()`.
///
/// ```swift
/// // doc-check: skip
/// let code = try check(sqlite3_step(statement), db: db, in: SQLITE_ROW, SQLITE_DONE)
/// if code == SQLITE_ROW {
///   // read column values
/// }
/// ```
///
/// - Returns: The code returned by `block`, guaranteed to be one of `results`.
@DatabaseActor
func check(
  _ block: @autoclosure () -> Int32,
  db: OpaquePointer? = nil,
  in results: Int32...
) throws -> Int32 {
  let code = block()
  guard !results.contains(code) else { return code }
  if let db {
    throw LoomError.sqlite(code, message: String(cString: sqlite3_errmsg(db)))
  } else {
    throw LoomError.sqlite(code, message: String(cString: sqlite3_errstr(code)))
  }
}
