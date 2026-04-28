// MARK: - Logical Operators

/// Logical operators for boolean expressions.
///
/// Combines SQL boolean expressions with the Swift `&&`, `||`, and `!` operators. Each operator
/// produces a composable expression tree that renders to parenthesized SQL when interpolated into
/// a statement.
///
/// ```swift
/// let age = ColumnExpression<Int>("age")
/// let status = ColumnExpression<String>("status")
/// let activeAdults = (age > 18) && (status == "active")
/// // Renders: ( ( "age" > ? ) AND ( "status" = ? ) )
/// ```

extension Expression where ExpressionValue == Bool {
  /// Combines two boolean expressions with SQL `AND`.
  ///
  /// ```swift
  /// let isActive = ColumnExpression<Bool>("is_active")
  /// let isVerified = ColumnExpression<Bool>("is_verified")
  /// let eligible = isActive && isVerified
  /// // Renders: ( "is_active" AND "is_verified" )
  /// ```
  public static func && <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == Bool {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "AND")
  }

  /// Combines two boolean expressions with SQL `OR`.
  ///
  /// ```swift
  /// let isAdmin = ColumnExpression<Bool>("is_admin")
  /// let isOwner = ColumnExpression<Bool>("is_owner")
  /// let canEdit = isAdmin || isOwner
  /// // Renders: ( "is_admin" OR "is_owner" )
  /// ```
  public static func || <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == Bool {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "OR")
  }

  /// Negates a boolean expression with SQL `NOT`.
  ///
  /// ```swift
  /// let isArchived = ColumnExpression<Bool>("is_archived")
  /// let visible = !isArchived
  /// // Renders: ( NOT "is_archived" )
  /// ```
  public static prefix func ! (operand: Self) -> UnaryOperation<Self, Bool> {
    UnaryOperation(operand: operand, sqlOperator: "NOT", isPrefix: true)
  }
}
