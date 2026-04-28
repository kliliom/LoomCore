import Foundation
import SQLite3

/// Type-safe wrapper around SQLite result codes.
///
/// Compares against named constants instead of the raw `Int32` values returned
/// by the SQLite C API. Pairs with ``LoomError`` to inspect failures from
/// database operations.
///
/// ```swift
/// do {
///   try await db.exec("INSERT INTO users (id, name) VALUES (?, ?)", 1, "Alice")
/// } catch let error as LoomError where error.sqlite == .constraint {
///   // Unique constraint violation — surface a friendly message to the caller.
/// }
/// ```
///
/// See [Result and Error Codes](https://sqlite.org/rescode.html) for the full list.
public struct SQLiteResultCode: RawRepresentable, Hashable, Sendable {
  public let rawValue: Int32

  public init(rawValue: Int32) {
    self.rawValue = rawValue
  }

  /// Operation aborted prior to completion, usually by application request.
  public static let abort = SQLiteResultCode(rawValue: SQLITE_ABORT)
  /// Authorizer callback denied authorization for an SQL statement being prepared.
  public static let auth = SQLiteResultCode(rawValue: SQLITE_AUTH)
  /// Database file could not be written because of concurrent activity by another connection.
  public static let busy = SQLiteResultCode(rawValue: SQLITE_BUSY)
  /// SQLite could not open a file.
  public static let cantOpen = SQLiteResultCode(rawValue: SQLITE_CANTOPEN)
  /// SQL constraint violation occurred while processing a statement.
  public static let constraint = SQLiteResultCode(rawValue: SQLITE_CONSTRAINT)
  /// Database file has been corrupted.
  public static let corrupt = SQLiteResultCode(rawValue: SQLITE_CORRUPT)
  /// Operation completed. Returned by `sqlite3_step()` when the statement has run to completion.
  public static let done = SQLiteResultCode(rawValue: SQLITE_DONE)
  /// Not currently used.
  public static let empty = SQLiteResultCode(rawValue: SQLITE_EMPTY)
  /// Generic error occurred; no more specific error code is available.
  public static let error = SQLiteResultCode(rawValue: SQLITE_ERROR)
  /// Not currently used.
  public static let format = SQLiteResultCode(rawValue: SQLITE_FORMAT)
  /// Write could not complete because the disk is full.
  public static let full = SQLiteResultCode(rawValue: SQLITE_FULL)
  /// Internal malfunction, indicating a bug in the database engine.
  public static let `internal` = SQLiteResultCode(rawValue: SQLITE_INTERNAL)
  /// Operation interrupted by `sqlite3_interrupt()`.
  public static let interrupt = SQLiteResultCode(rawValue: SQLITE_INTERRUPT)
  /// Operating system reported an I/O error.
  public static let ioError = SQLiteResultCode(rawValue: SQLITE_IOERR)
  /// Write operation blocked by a conflict within the same or a shared-cache database connection.
  public static let locked = SQLiteResultCode(rawValue: SQLITE_LOCKED)
  /// Datatype mismatch, such as attempting to set a rowid to a non-integer value.
  public static let mismatch = SQLiteResultCode(rawValue: SQLITE_MISMATCH)
  /// Application used an SQLite interface in a way that is undefined or unsupported.
  public static let misuse = SQLiteResultCode(rawValue: SQLITE_MISUSE)
  /// System does not support large files and the database grew beyond what the filesystem can handle.
  public static let noLFS = SQLiteResultCode(rawValue: SQLITE_NOLFS)
  /// SQLite could not allocate the required memory.
  public static let noMemory = SQLiteResultCode(rawValue: SQLITE_NOMEM)
  /// File being opened does not appear to be an SQLite database file.
  public static let notADatabase = SQLiteResultCode(rawValue: SQLITE_NOTADB)
  /// File control opcode was not recognized, or a requested resource could not be found.
  public static let notFound = SQLiteResultCode(rawValue: SQLITE_NOTFOUND)
  /// Used in `sqlite3_log()` callbacks to indicate that an unusual operation is taking place.
  public static let notice = SQLiteResultCode(rawValue: SQLITE_NOTICE)
  /// Operation completed successfully.
  public static let ok = SQLiteResultCode(rawValue: SQLITE_OK)
  /// Requested access mode for a newly created database could not be provided.
  public static let permission = SQLiteResultCode(rawValue: SQLITE_PERM)
  /// Problem with the file locking protocol, currently only returned in WAL mode.
  public static let `protocol` = SQLiteResultCode(rawValue: SQLITE_PROTOCOL)
  /// Parameter number or column number argument is out of range.
  public static let range = SQLiteResultCode(rawValue: SQLITE_RANGE)
  /// Current database connection does not have write permission.
  public static let readOnly = SQLiteResultCode(rawValue: SQLITE_READONLY)
  /// Row of output is available. Returned by `sqlite3_step()`.
  public static let row = SQLiteResultCode(rawValue: SQLITE_ROW)
  /// Database schema has changed since a prepared statement was generated.
  public static let schema = SQLiteResultCode(rawValue: SQLITE_SCHEMA)
  /// String or BLOB exceeded the maximum allowed length.
  public static let tooBig = SQLiteResultCode(rawValue: SQLITE_TOOBIG)
  /// Used in `sqlite3_log()` callbacks to indicate that an unusual and possibly ill-advised operation is taking place.
  public static let warning = SQLiteResultCode(rawValue: SQLITE_WARNING)
}

extension SQLiteResultCode: CustomDebugStringConvertible {
  /// Returns the matching `SQLITE_*` macro name, or `SQLITE_RESULT_CODE(<raw>)` for an unrecognized code.
  public var debugDescription: String {
    switch self {
    case .abort: return "SQLITE_ABORT"
    case .auth: return "SQLITE_AUTH"
    case .busy: return "SQLITE_BUSY"
    case .cantOpen: return "SQLITE_CANTOPEN"
    case .constraint: return "SQLITE_CONSTRAINT"
    case .corrupt: return "SQLITE_CORRUPT"
    case .done: return "SQLITE_DONE"
    case .empty: return "SQLITE_EMPTY"
    case .error: return "SQLITE_ERROR"
    case .format: return "SQLITE_FORMAT"
    case .full: return "SQLITE_FULL"
    case .`internal`: return "SQLITE_INTERNAL"
    case .interrupt: return "SQLITE_INTERRUPT"
    case .ioError: return "SQLITE_IOERR"
    case .locked: return "SQLITE_LOCKED"
    case .mismatch: return "SQLITE_MISMATCH"
    case .misuse: return "SQLITE_MISUSE"
    case .noLFS: return "SQLITE_NOLFS"
    case .noMemory: return "SQLITE_NOMEM"
    case .notADatabase: return "SQLITE_NOTADB"
    case .notFound: return "SQLITE_NOTFOUND"
    case .notice: return "SQLITE_NOTICE"
    case .ok: return "SQLITE_OK"
    case .permission: return "SQLITE_PERM"
    case .`protocol`: return "SQLITE_PROTOCOL"
    case .range: return "SQLITE_RANGE"
    case .readOnly: return "SQLITE_READONLY"
    case .row: return "SQLITE_ROW"
    case .schema: return "SQLITE_SCHEMA"
    case .tooBig: return "SQLITE_TOOBIG"
    case .warning: return "SQLITE_WARNING"
    default: return "SQLITE_RESULT_CODE(\(rawValue))"
    }
  }
}

extension SQLiteResultCode: LoomError.ErrorCode {}

extension LoomError {
  /// Builds a `LoomError` from a raw SQLite result code and message.
  ///
  /// Wraps a result code returned by the SQLite C API into a typed
  /// ``SQLiteResultCode`` and attaches it to a `LoomError` for surfacing
  /// through the throwing API surface.
  ///
  /// ```swift
  /// guard sqlite3_step(stmt) == SQLITE_DONE else {
  ///   let raw = sqlite3_errcode(handle)
  ///   let msg = String(cString: sqlite3_errmsg(handle))
  ///   throw LoomError.sqlite(raw, message: msg)
  /// }
  /// ```
  public static func sqlite(_ code: Int32, message: String) -> LoomError {
    LoomError(code: SQLiteResultCode(rawValue: code), message: message)
  }
}

extension LoomError {
  /// Returns the underlying ``SQLiteResultCode`` when the error originated from SQLite, otherwise `nil`.
  ///
  /// ```swift
  /// do {
  ///   try await db.exec("INSERT INTO users (id) VALUES (?)", 1)
  /// } catch let error as LoomError {
  ///   switch error.sqlite {
  ///   case .constraint: showDuplicateMessage()
  ///   case .readOnly:   showReadOnlyMessage()
  ///   default:          rethrow(error)
  ///   }
  /// }
  /// ```
  public var sqlite: SQLiteResultCode? {
    if let code = code as? SQLiteResultCode {
      return code
    }
    return nil
  }
}
