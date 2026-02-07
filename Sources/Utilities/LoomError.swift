import Foundation
import SQLite3

/// A general error type for Loom, which can represent both core errors and SQLite errors.
public struct LoomError: Error {
  /// A protocol that all error codes used in `LoomError` must conform to.
  public protocol ErrorCode: Hashable, Sendable {}

  /// The specific error code associated with this error, which can be of any type conforming to `ErrorCode`.
  public let code: any ErrorCode
  /// A descriptive message providing more details about the error.
  public let message: String

  /// Initializes a new `LoomError` with the given error code and message.
  /// - Parameters:
  ///   - code: The specific error code representing the type of error.
  ///   - message: A descriptive message providing more details about the error.
  public init(code: any ErrorCode, message: String) {
    self.code = code
    self.message = message
  }
}

extension LoomError: Hashable {
  public static func == (lhs: LoomError, rhs: LoomError) -> Bool {
    lhs.code.isEqual(to: rhs.code) && lhs.message == rhs.message
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(code)
    hasher.combine(message)
  }
}

extension LoomError.ErrorCode {
  /// Compares this error code to another for equality.
  /// - Parameter other: Another error code to compare against.
  /// - Returns: `true` if the error codes are considered equal, `false` otherwise.
  func isEqual(to other: any LoomError.ErrorCode) -> Bool {
    guard let other = other as? Self else {
      return false
    }
    return self == other
  }
}
