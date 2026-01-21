public protocol Expression<ExpressionValue>: Sendable {
  associatedtype ExpressionValue

  /// Appends the SQL representation to the builder.
  /// - Parameter builder: SQL builder.
  func append(to builder: inout SQLBuilder)
}
