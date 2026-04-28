// MARK: - String Operators

/// String operators for text expressions.
///
/// These operators enable SQL pattern matching operations on string expressions.
///
/// Example:
/// ```swift
/// let name = ColumnExpression<String>("name")
/// let condition = name.like("Admin%")
/// // Generates: (name LIKE ?)
/// ```
public struct LikeExpression<Left: Expression, Right: Expression>: Expression
where Left.ExpressionValue == String, Right.ExpressionValue == String {
  public typealias ExpressionValue = Bool

  public enum LikeType: Sendable {
    case like
    case notLike
  }

  /// The left-hand side expression.
  let left: Left

  /// The right-hand side expression.
  let right: Right

  /// The type of LIKE operation (LIKE or NOT LIKE).
  let likeType: LikeType

  /// Escape character for treating `%` and `_` as literals (optional).
  let escape: Character?

  public init(left: Left, right: Right, likeType: LikeType = .like, escape: Character? = nil) {
    self.left = left
    self.right = right
    self.likeType = likeType
    self.escape = escape
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("(")
    left.append(to: &builder)
    switch likeType {
    case .like:
      builder.appendLiteral("LIKE")
    case .notLike:
      builder.appendLiteral("NOT LIKE")
    }
    right.append(to: &builder)
    if let escape = escape {
      builder.appendLiteral("ESCAPE '\(escape)'")
    }
    builder.appendLiteral(")")
  }
}

extension Expression where ExpressionValue == String {
  /// SQL LIKE pattern matching operator.
  ///
  /// Use `%` to match any sequence of characters and `_` to match a single character.
  ///
  /// Example:
  /// ```swift
  /// let name = ColumnExpression<String>("name")
  /// name.like("John%")  // Matches names starting with "John"
  /// name.like("%Smith") // Matches names ending with "Smith"
  /// name.like("J_n")    // Matches "Jon", "Jan", "Jin", etc.
  /// // Generates: (name LIKE ?)
  /// name.like("100\\%", escape: "\\") // Matches "100%" if escape character is set to "\\"
  /// // Generates: (name LIKE ? ESCAPE '\')
  /// ```
  ///
  /// - Parameters:
  ///   - pattern: The pattern to match, using `%` and `_` wildcards.
  ///   - escape: An optional escape character to treat `%` and `_` as literals.
  /// - Returns: A binary operation expression representing the SQL LIKE operation.
  public func like<R: Expression>(_ pattern: R, escape: Character? = nil) -> LikeExpression<Self, R>
  where R.ExpressionValue == String {
    LikeExpression(left: self, right: pattern, likeType: .like, escape: escape)
  }

  /// SQL NOT LIKE pattern matching operator.
  ///
  /// Use `%` to match any sequence of characters and `_` to match a single character.
  ///
  /// Example:
  /// ```swift
  /// let name = ColumnExpression<String>("name")
  /// name.notLike("John%")  // Matches names not starting with "John"
  /// name.notLike("%Smith") // Matches names not ending with "Smith"
  /// name.notLike("J_n")    // Matches names not "Jon", "Jan", "Jin", etc.
  /// // Generates: (name NOT LIKE ?)
  /// name.notLike("100\\%", escape: "\\") // Matches names not "100%" if escape character is set to "\\"
  /// // Generates: (name NOT LIKE ? ESCAPE '\')
  /// ```
  ///
  /// - Parameters:
  ///   - pattern: The pattern to match, using `%` and `_` wildcards.
  ///   - escape: An optional escape character to treat `%` and `_` as literals.
  /// - Returns: A binary operation expression representing the SQL NOT LIKE operation.
  public func notLike<R: Expression>(_ pattern: R, escape: Character? = nil) -> LikeExpression<Self, R>
  where R.ExpressionValue == String {
    LikeExpression(left: self, right: pattern, likeType: .notLike, escape: escape)
  }
}
