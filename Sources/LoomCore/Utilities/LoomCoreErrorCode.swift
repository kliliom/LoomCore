import Foundation
import SQLite3

/// Error codes raised by LoomCore itself.
///
/// Wrap one of these in a `LoomError` via `LoomError.core(_:message:)`, or read it back from
/// a caught error via `LoomError.core`.
///
/// ```swift
/// do {
///   try await db.exec("SELECT 1")
/// } catch let error as LoomError where error.core == .databaseClosed {
///   // Reopen and retry, or surface a "connection lost" message.
/// }
/// ```
public struct LoomCoreErrorCode: RawRepresentable, Hashable, Sendable {
  public let rawValue: Int32

  public init(rawValue: Int32) {
    self.rawValue = rawValue
  }

  /// Unexpected internal state — typically signals a bug in LoomCore.
  public static let unexpectedState = LoomCoreErrorCode(rawValue: 1)
  /// Operation attempted on a database connection that has already been closed.
  public static let databaseClosed = LoomCoreErrorCode(rawValue: 2)
  /// Database path is malformed or cannot be resolved to a writable location.
  public static let invalidDatabasePath = LoomCoreErrorCode(rawValue: 3)
  /// Null value encountered in a column or parameter that does not permit nulls.
  public static let nullValue = LoomCoreErrorCode(rawValue: 4)
  /// Stored value could not be decoded into the requested Swift type.
  public static let typeMappingFailed = LoomCoreErrorCode(rawValue: 5)
  /// SQL string contained more than one statement where exactly one was expected.
  ///
  /// Raised by the `exec` and `query` families, which prepare a single statement. Also
  /// raised when the SQL contains an embedded NUL byte, since SQLite would silently drop
  /// everything after it. Run multi-statement scripts through ``Database/execScript(_:)``
  /// instead.
  public static let trailingSQL = LoomCoreErrorCode(rawValue: 6)
  /// Script handed to ``Database/execScript(_:)`` violated its contract.
  ///
  /// Raised when a script contains a parameter placeholder such as `?` or `:name` (script
  /// statements take no bound parameters), contains an embedded NUL byte (everything after it would be silently
  /// dropped), leaves a transaction open at the end, or ends the enclosing
  /// ``Database/transaction(kind:_:)`` with a `COMMIT`/`ROLLBACK` of its own.
  public static let invalidScript = LoomCoreErrorCode(rawValue: 7)
  /// Transaction scope tried to close after losing control of the connection.
  ///
  /// Raised in place of the scope's `COMMIT`/`RELEASE` when the database was closed
  /// mid-flight, or when an enclosing scope exited while this scope was still open —
  /// typically an un-awaited `Task {}` that outlived the ``Database/transaction(kind:_:)``
  /// body it was spawned from. The scope's writes were committed or rolled back together
  /// with the enclosing scope; the refused close never touches the connection.
  public static let transactionScopeLost = LoomCoreErrorCode(rawValue: 8)
}

extension LoomCoreErrorCode: LoomError.ErrorCode {}

extension LoomError {
  /// Builds a `LoomError` carrying a `LoomCoreErrorCode`.
  ///
  /// ```swift
  /// let url = URL(fileURLWithPath: "/tmp/app.sqlite")
  /// guard url.isFileURL else {
  ///   throw LoomError.core(.invalidDatabasePath, message: "URL has no filesystem path: \(url)")
  /// }
  /// ```
  public static func core(_ code: LoomCoreErrorCode, message: String) -> LoomError {
    LoomError(code: code, message: message)
  }
}

extension LoomError {
  /// Underlying `LoomCoreErrorCode`, or `nil` if this error originated from a different code domain.
  ///
  /// ```swift
  /// func reconnect() async {}
  ///
  /// do {
  ///   try await db.exec("SELECT 1")
  /// } catch let error as LoomError {
  ///   switch error.core {
  ///   case .databaseClosed: await reconnect()
  ///   case .typeMappingFailed: print("schema drift: \(error.message)")
  ///   default: throw error
  ///   }
  /// }
  /// ```
  public var core: LoomCoreErrorCode? {
    if let code = code as? LoomCoreErrorCode {
      return code
    }
    return nil
  }
}
