import Foundation
import SQLite3

public struct LoomCoreErrorCode: RawRepresentable, Hashable, Sendable {
  public let rawValue: Int32

  public init(rawValue: Int32) {
    self.rawValue = rawValue
  }

  /// An unexpected state was encountered.
  public static let unexpectedState = LoomCoreErrorCode(rawValue: 1)
  /// An operation was attempted on a database connection that has already been closed.
  public static let databaseClosed = LoomCoreErrorCode(rawValue: 2)
  /// An invalid database path was provided.
  public static let invalidDatabasePath = LoomCoreErrorCode(rawValue: 3)
  /// A null value was encountered where it is not allowed.
  public static let nullValue = LoomCoreErrorCode(rawValue: 4)
  /// A value could not be mapped to the expected type.
  public static let typeMappingFailed = LoomCoreErrorCode(rawValue: 5)
}

extension LoomCoreErrorCode: LoomError.ErrorCode {}

extension LoomError {
  /// Creates a `LoomError` with the given `LoomCoreErrorCode` and message.
  /// - Parameters:
  ///   - code: The `LoomCoreErrorCode` representing the error type.
  ///   - message: A descriptive message for the error.
  /// - Returns: A `LoomError` instance representing the core error.
  public static func core(_ code: LoomCoreErrorCode, message: String) -> LoomError {
    LoomError(code: code, message: message)
  }
}

extension LoomError {
  /// Retrieves the `LoomCoreErrorCode` if the error's code is of that type.
  public var core: LoomCoreErrorCode? {
    if let code = code as? LoomCoreErrorCode {
      return code
    }
    return nil
  }
}
