import Foundation
import SQLite3

/// Stores dictionaries with `Bindable` keys and values as JSON-encoded BLOB columns.
///
/// The dictionary is bound as a single parameter — its JSON representation — rather than
/// expanded into separate columns or rows.
///
/// ```swift
/// struct FeatureFlags: Codable {
///   let userID: Int
///   let flags: [String: Bool]
/// }
///
/// let flags = FeatureFlags(userID: 1, flags: ["darkMode": true])
/// try await db.exec(
///   "INSERT INTO feature_flags (user_id, flags) VALUES (\(flags.userID), \(flags.flags))"
/// )
/// ```
extension Dictionary: Expression where Self: Codable, Key: Bindable, Value: Bindable {
  public typealias ExpressionValue = Self

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("?")
    builder.appendBinder(managedBinder)
  }
}

extension Dictionary: Bindable where Self: Codable, Key: Bindable, Value: Bindable {}
