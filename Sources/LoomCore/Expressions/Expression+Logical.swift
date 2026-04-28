// MARK: - Logical Operators

/// Logical operators for boolean expressions.
///
/// These operators enable natural logical operations on SQL expressions.
/// Both optional and non-optional Bool expressions are supported.
///
/// Example:
/// ```swift
/// let age = ColumnExpression<Int>("age")
/// let status = ColumnExpression<String>("status")
/// let condition = (age > 18) && (status == "active")
/// // Generates: ((age > ?) AND (status = ?))
/// ```

extension Expression where ExpressionValue == Bool {
  /// Logical AND operator for non-optional boolean expressions.
  ///
  /// Example:
  /// ```swift
  /// let isActive = ColumnExpression<Bool>("is_active")
  /// let isVerified = ColumnExpression<Bool>("is_verified")
  /// let condition = isActive && isVerified
  /// // Generates: (is_active AND is_verified)
  /// ```
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side expression.
  ///   - rhs: The right-hand side expression.
  /// - Returns: A binary operation expression representing the logical AND.
  public static func && <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == Bool {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "AND")
  }

  /// Logical OR operator for non-optional boolean expressions.
  ///
  /// Example:
  /// ```swift
  /// let isActive = ColumnExpression<Bool>("is_active")
  /// let isVerified = ColumnExpression<Bool>("is_verified")
  /// let condition = isActive || isVerified
  /// // Generates: (is_active OR is_verified)
  /// ```
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side expression.
  ///   - rhs: The right-hand side expression.
  /// - Returns: A binary operation expression representing the logical OR.
  public static func || <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == Bool {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "OR")
  }

  /// Logical NOT operator for non-optional boolean expressions.
  ///
  /// Example:
  /// ```swift
  /// let isActive = ColumnExpression<Bool>("is_active")
  /// let condition = !isActive
  /// // Generates: (NOT is_active)
  /// ```
  ///
  public static prefix func ! (operand: Self) -> UnaryOperation<Self, Bool> {
    UnaryOperation(operand: operand, sqlOperator: "NOT", isPrefix: true)
  }
}
