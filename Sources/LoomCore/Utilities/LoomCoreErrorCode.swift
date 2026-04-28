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
}

extension LoomCoreErrorCode: LoomError.ErrorCode {}

extension LoomError {
  /// Builds a `LoomError` carrying a `LoomCoreErrorCode`.
  ///
  /// ```swift
  /// guard let path = url.path else {
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
  /// catch let error as LoomError {
  ///   switch error.core {
  ///   case .databaseClosed: await reconnect()
  ///   case .typeMappingFailed: log.warning("schema drift: \(error.message)")
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
