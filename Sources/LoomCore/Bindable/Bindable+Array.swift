import Foundation
import SQLite3

/// Stores arrays of `Bindable` elements as JSON-encoded BLOB columns.
///
/// The array is bound as a single parameter — its JSON representation — rather than
/// expanded into a list of placeholders. For SQL `IN` lists, use `InExpression` instead.
///
/// ```swift
/// struct Post: Codable {
///   let id: Int
///   let tags: [String]
/// }
///
/// let post = Post(id: 1, tags: ["swift", "sqlite"])
/// try await db.exec(
///   "INSERT INTO posts (id, tags) VALUES (\(post.id), \(post.tags))"
/// )
/// ```
extension Array: Expression where Self: Codable, Element: Bindable {
  public typealias ExpressionValue = Self

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("?")
    builder.appendBinder(managedBinder)
  }
}

extension Array: Bindable where Self: Codable, Element: Bindable {}
