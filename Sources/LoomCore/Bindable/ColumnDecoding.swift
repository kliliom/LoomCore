import Foundation
import SQLite3

/// Set of SQLite storage classes a column decoder accepts.
struct StorageClassSet: OptionSet {
  let rawValue: UInt8

  static let integer = StorageClassSet(rawValue: 1 << 0)
  static let real = StorageClassSet(rawValue: 1 << 1)
  static let text = StorageClassSet(rawValue: 1 << 2)
  static let blob = StorageClassSet(rawValue: 1 << 3)

  init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  init?(columnType: Int32) {
    switch columnType {
    case SQLITE_INTEGER: self = .integer
    case SQLITE_FLOAT: self = .real
    case SQLITE_TEXT: self = .text
    case SQLITE_BLOB: self = .blob
    default: return nil
    }
  }

  var name: String {
    switch self {
    case .integer: "INTEGER"
    case .real: "REAL"
    case .text: "TEXT"
    case .blob: "BLOB"
    default: "unknown"
    }
  }
}

/// Validates the storage class of the column at 0-based `index` before decoding it as `type`.
///
/// Throws `LoomError.core(.nullValue, …)` for `SQLITE_NULL` and `LoomError.core(.typeMappingFailed, …)`
/// for any storage class outside `accepted`. Returns the actual `sqlite3_column_type` code so callers
/// that accept multiple classes can branch on it.
@DatabaseActor
func requireStorageClass(
  of stmt: borrowing StatementHandle,
  at index: Int32,
  oneOf accepted: StorageClassSet,
  for type: Any.Type
) throws -> Int32 {
  let actual = sqlite3_column_type(stmt.stmtPtr, index)
  if actual == SQLITE_NULL {
    throw LoomError.core(.nullValue, message: "Column at index \(index) is NULL, cannot return \(type).")
  }
  guard let actualClass = StorageClassSet(columnType: actual), accepted.contains(actualClass) else {
    let name = StorageClassSet(columnType: actual)?.name ?? "unknown"
    throw LoomError.core(
      .typeMappingFailed,
      message: "Column at index \(index) has storage class \(name), cannot return \(type)."
    )
  }
  return actual
}

/// Distinguishes a zero-length column payload from an allocation failure after
/// `sqlite3_column_blob`/`sqlite3_column_text` returned a nil pointer.
///
/// `sqlite3_errcode` reports non-error codes such as `SQLITE_ROW` after successful calls, so only
/// `SQLITE_NOMEM` is treated as failure.
@DatabaseActor
func checkColumnAllocation(of stmt: borrowing StatementHandle) throws {
  if sqlite3_errcode(stmt.dbPtr) == SQLITE_NOMEM {
    throw LoomError.sqlite(SQLITE_NOMEM, message: String(cString: sqlite3_errmsg(stmt.dbPtr)))
  }
}
