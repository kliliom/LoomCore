// MARK: - Comparison Operators

/// Comparison operators for expressions.
///
/// These operators enable natural comparison operations on SQL expressions.
///
/// Example:
/// ```swift
/// let price = ColumnExpression<Int>("price")
/// let condition = price >= 1000
/// // Generates: (price >= ?)
/// ```

extension Expression where ExpressionValue: Equatable {
  /// Equality comparison operator.
  ///
  /// Example:
  /// ```swift
  /// let price = ColumnExpression<Int>("price")
  /// let condition = price == 1000
  /// // Generates: (price = ?)
  /// ```
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side expression.
  ///   - rhs: The right-hand side expression.
  /// - Returns: A binary operation expression representing the equality comparison.
  public static func == <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "=")
  }

  /// Inequality comparison operator.
  ///
  /// Example:
  /// ```swift
  /// let price = ColumnExpression<Int>("price")
  /// let condition = price != 1000
  /// // Generates: (price <> ?)
  /// ```
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side expression.
  ///   - rhs: The right-hand side expression.
  /// - Returns: A binary operation expression representing the inequality comparison.
  public static func != <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "<>")
  }
}

extension Expression where ExpressionValue: Comparable {
  /// Less than comparison operator.
  ///
  /// Example:
  /// ```swift
  /// let price = ColumnExpression<Int>("price")
  /// let condition = price < 1000
  /// // Generates: (price < ?)
  /// ```
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side expression.
  ///   - rhs: The right-hand side expression.
  /// - Returns: A binary operation expression representing the less than comparison.
  public static func < <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "<")
  }

  /// Greater than comparison operator.
  ///
  /// Example:
  /// ```swift
  /// let price = ColumnExpression<Int>("price")
  /// let condition = price > 1000
  /// // Generates: (price > ?)
  /// ```
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side expression.
  ///   - rhs: The right-hand side expression.
  /// - Returns: A binary operation expression representing the greater than comparison.
  public static func > <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: ">")
  }

  /// Less than or equal comparison operator.
  ///
  /// Example:
  /// ```swift
  /// let price = ColumnExpression<Int>("price")
  /// let condition = price <= 1000
  /// // Generates: (price <= ?)
  /// ```
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side expression.
  ///   - rhs: The right-hand side expression.
  /// - Returns: A binary operation expression representing the less than or equal comparison.
  public static func <= <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "<=")
  }

  /// Greater than or equal comparison operator.
  ///
  /// Example:
  /// ```swift
  /// let price = ColumnExpression<Int>("price")
  /// let condition = price >= 1000
  /// // Generates: (price >= ?)
  /// ```
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side expression.
  ///   - rhs: The right-hand side expression.
  /// - Returns: A binary operation expression representing the greater than or equal comparison.
  public static func >= <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: ">=")
  }
}
