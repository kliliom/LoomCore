// MARK: - String Operators

/// Pattern-match expression rendering SQL `LIKE` or `NOT LIKE`.
///
/// Build instances through the `like(_:escape:)` and `notLike(_:escape:)` operators on any
/// `String`-valued expression — direct construction is rarely needed.
///
/// ```swift
/// let email = ColumnExpression<String>("email")
/// let admins = try await db.query("SELECT id FROM users WHERE \(email.like("admin@%"))") { stmt, _ in
///   try Int64.column(of: stmt, at: 0)
/// }
/// ```
public struct LikeExpression<Left: Expression, Right: Expression>: Expression
where Left.ExpressionValue == String, Right.ExpressionValue == String {
  public typealias ExpressionValue = Bool

  /// Variant of the pattern match: `LIKE` or `NOT LIKE`.
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

  /// Creates a pattern-match expression comparing `left` against `right`.
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
    if let escape {
      // Rendered as a quote-doubled literal, not a bound parameter: SQLite applies the
      // LIKE prefix-index optimization only when the ESCAPE operand is a literal token,
      // so binding it would silently turn every indexed LIKE into a full-table scan.
      builder.appendLiteral("ESCAPE '\(String(escape).doublingOccurrences(of: "'"))'")
    }
    builder.appendLiteral(")")
  }
}

extension Expression where ExpressionValue == String {
  /// Tests whether the expression matches a SQL `LIKE` pattern.
  ///
  /// `%` matches any sequence of characters; `_` matches exactly one character. Pass `escape`
  /// to treat `%` or `_` as literals — the chosen character precedes the literal in the pattern.
  ///
  /// ```swift
  /// let email = ColumnExpression<String>("email")
  ///
  /// // Find all admin addresses.
  /// let admins = try await db.query("SELECT id FROM users WHERE \(email.like("admin@%"))") { stmt, _ in
  ///   try Int64.column(of: stmt, at: 0)
  /// }
  ///
  /// // Find rows whose comment column literally contains "100%".
  /// let comment = ColumnExpression<String>("comment")
  /// let promos = try await db.query(
  ///   "SELECT id FROM offers WHERE \(comment.like("%100\\%%", escape: "\\"))"
  /// ) { stmt, _ in
  ///   try Int64.column(of: stmt, at: 0)
  /// }
  /// ```
  public func like<R: Expression>(_ pattern: R, escape: Character? = nil) -> LikeExpression<Self, R>
  where R.ExpressionValue == String {
    LikeExpression(left: self, right: pattern, likeType: .like, escape: escape)
  }

  /// Tests whether the expression does not match a SQL `LIKE` pattern.
  ///
  /// `%` matches any sequence of characters; `_` matches exactly one character. Pass `escape`
  /// to treat `%` or `_` as literals — the chosen character precedes the literal in the pattern.
  ///
  /// ```swift
  /// let email = ColumnExpression<String>("email")
  ///
  /// // Find users whose address is not on the corporate domain.
  /// let external = try await db.query(
  ///   "SELECT id FROM users WHERE \(email.notLike("%@example.com"))"
  /// ) { stmt, _ in
  ///   try Int64.column(of: stmt, at: 0)
  /// }
  /// ```
  public func notLike<R: Expression>(_ pattern: R, escape: Character? = nil) -> LikeExpression<Self, R>
  where R.ExpressionValue == String {
    LikeExpression(left: self, right: pattern, likeType: .notLike, escape: escape)
  }
}
