import Foundation
import SQLite3

/// A type-safe wrapper around SQLite result codes.
///
/// See [Result and Error Codes](https://sqlite.org/rescode.html) for details.
public struct SQLiteResultCode: RawRepresentable, Hashable, Sendable {
  public let rawValue: Int32

  public init(rawValue: Int32) {
    self.rawValue = rawValue
  }

  /// An operation was aborted prior to completion, usually by application request.
  public static let abort = SQLiteResultCode(rawValue: SQLITE_ABORT)
  /// The authorizer callback indicated that an SQL statement being prepared is not authorized.
  public static let auth = SQLiteResultCode(rawValue: SQLITE_AUTH)
  /// The database file could not be written because of concurrent activity by another database connection.
  public static let busy = SQLiteResultCode(rawValue: SQLITE_BUSY)
  /// SQLite was unable to open a file.
  public static let cantOpen = SQLiteResultCode(rawValue: SQLITE_CANTOPEN)
  /// An SQL constraint violation occurred while trying to process an SQL statement.
  public static let constraint = SQLiteResultCode(rawValue: SQLITE_CONSTRAINT)
  /// The database file has been corrupted.
  public static let corrupt = SQLiteResultCode(rawValue: SQLITE_CORRUPT)
  /// An operation has completed. Returned by `sqlite3_step()` when the SQL statement has run to completion.
  public static let done = SQLiteResultCode(rawValue: SQLITE_DONE)
  /// Not currently used.
  public static let empty = SQLiteResultCode(rawValue: SQLITE_EMPTY)
  /// A generic error occurred and no more specific error code is available.
  public static let error = SQLiteResultCode(rawValue: SQLITE_ERROR)
  /// Not currently used.
  public static let format = SQLiteResultCode(rawValue: SQLITE_FORMAT)
  /// A write could not complete because the disk is full.
  public static let full = SQLiteResultCode(rawValue: SQLITE_FULL)
  /// An internal malfunction, indicating a bug in the database engine.
  public static let `internal` = SQLiteResultCode(rawValue: SQLITE_INTERNAL)
  /// An operation was interrupted by `sqlite3_interrupt()`.
  public static let interrupt = SQLiteResultCode(rawValue: SQLITE_INTERRUPT)
  /// The operating system reported an I/O error.
  public static let ioError = SQLiteResultCode(rawValue: SQLITE_IOERR)
  /// A write operation could not continue because of a conflict within the same or a shared-cache database connection.
  public static let locked = SQLiteResultCode(rawValue: SQLITE_LOCKED)
  /// A datatype mismatch occurred, such as attempting to set a rowid to a non-integer value.
  public static let mismatch = SQLiteResultCode(rawValue: SQLITE_MISMATCH)
  /// The application used an SQLite interface in a way that is undefined or unsupported.
  public static let misuse = SQLiteResultCode(rawValue: SQLITE_MISUSE)
  /// The system does not support large files and the database grew beyond what the filesystem can handle.
  public static let noLFS = SQLiteResultCode(rawValue: SQLITE_NOLFS)
  /// SQLite was unable to allocate all the memory it needed.
  public static let noMemory = SQLiteResultCode(rawValue: SQLITE_NOMEM)
  /// The file being opened does not appear to be an SQLite database file.
  public static let notADatabase = SQLiteResultCode(rawValue: SQLITE_NOTADB)
  /// A file control opcode was not recognized, or a requested resource could not be found.
  public static let notFound = SQLiteResultCode(rawValue: SQLITE_NOTFOUND)
  /// Used in `sqlite3_log()` callbacks to indicate that an unusual operation is taking place.
  public static let notice = SQLiteResultCode(rawValue: SQLITE_NOTICE)
  /// The operation was successful.
  public static let ok = SQLiteResultCode(rawValue: SQLITE_OK)
  /// The requested access mode for a newly created database could not be provided.
  public static let permission = SQLiteResultCode(rawValue: SQLITE_PERM)
  /// A problem with the file locking protocol, currently only returned when using WAL mode.
  public static let `protocol` = SQLiteResultCode(rawValue: SQLITE_PROTOCOL)
  /// A parameter number or column number argument is out of range.
  public static let range = SQLiteResultCode(rawValue: SQLITE_RANGE)
  /// The current database connection does not have write permission.
  public static let readOnly = SQLiteResultCode(rawValue: SQLITE_READONLY)
  /// Another row of output is available. Returned by `sqlite3_step()`.
  public static let row = SQLiteResultCode(rawValue: SQLITE_ROW)
  /// The database schema has changed since a prepared statement was generated.
  public static let schema = SQLiteResultCode(rawValue: SQLITE_SCHEMA)
  /// A string or BLOB exceeded the maximum allowed length.
  public static let tooBig = SQLiteResultCode(rawValue: SQLITE_TOOBIG)
  /// Used in `sqlite3_log()` callbacks to indicate that an unusual and possibly ill-advised operation is taking place.
  public static let warning = SQLiteResultCode(rawValue: SQLITE_WARNING)
}

extension SQLiteResultCode: CustomDebugStringConvertible {
  /// Returns a human-readable description of the result code.
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
  /// Creates a `LoomError` with a `SQLiteResultCode` and a message.
  /// - Parameters:
  ///   - code: The raw SQLite result code.
  ///   - message: A descriptive message for the error.
  /// - Returns: A `LoomError` instance representing the SQLite error.
  public static func sqlite(_ code: Int32, message: String) -> LoomError {
    LoomError(code: SQLiteResultCode(rawValue: code), message: message)
  }
}

extension LoomError {
  /// Retrieves the `SQLiteResultCode` if the error's code is of that type.
  public var sqlite: SQLiteResultCode? {
    if let code = code as? SQLiteResultCode {
      return code
    }
    return nil
  }
}
