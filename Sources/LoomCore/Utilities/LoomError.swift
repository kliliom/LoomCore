import Foundation
import SQLite3

/// Error type used throughout LoomCore, pairing a typed error code with a human-readable message.
///
/// Each subsystem supplies its own `ErrorCode`-conforming enum so failures from different layers
/// (parameter binding, statement preparation, raw SQLite results) can flow through a single
/// `Error` type while remaining identifiable by their code.
///
/// ```swift
/// do {
///   try await database.execute("INSERT INTO users (name) VALUES (\(name))")
/// } catch let error as LoomError {
///   logger.error("\(error.message)")
///   throw error
/// }
/// ```
public struct LoomError: Error {
  /// Marker protocol that error code types must conform to in order to be carried by `LoomError`.
  ///
  /// Conforming types are typically subsystem-scoped enums. `Hashable` lets codes participate in
  /// pattern matching and set membership; `Sendable` allows them to cross actor boundaries.
  public protocol ErrorCode: Hashable, Sendable {}

  /// Code identifying the kind of failure.
  public let code: any ErrorCode

  /// Human-readable description of the failure.
  public let message: String

  /// Creates a `LoomError` with the given code and message.
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
