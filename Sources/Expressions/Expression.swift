/// A protocol representing an SQL expression that can be used in queries.
///
/// Expressions are the building blocks of SQL queries, representing values, columns,
/// functions, and other SQL constructs. Each expression has an associated value type
/// that represents the type of data it produces.
///
/// Types conforming to `Expression` must be `Sendable` to ensure thread safety across
/// concurrent contexts.
public protocol Expression<ExpressionValue>: Sendable {
  /// The type of value this expression produces.
  associatedtype ExpressionValue

  /// Appends the SQL representation of this expression to the builder.
  ///
  /// - Parameter builder: The SQL builder to append to.
  func append(to builder: inout SQLBuilder)
}

extension Expression {
  /// Type-erases this expression to an existential type.
  ///
  /// This method allows you to convert a concrete expression type to the existential
  /// `any Expression<ExpressionValue>` type, which can be useful when working with
  /// heterogeneous collections of expressions.
  ///
  /// - Returns: The same expression wrapped as an existential type.
  public func eraseToAnyExpression() -> any Expression<ExpressionValue> {
    self
  }
}
