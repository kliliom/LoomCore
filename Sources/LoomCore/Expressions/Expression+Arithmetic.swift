// MARK: - Arithmetic Operators

/// Arithmetic operators for numeric expressions.
///
/// These operators enable natural arithmetic operations on SQL expressions:
/// ```swift
/// let price = ColumnExpression<Double>("price")
/// let discount = ColumnExpression<Double>("discount")
/// let total = price - discount
/// // Generates: (price - discount)
/// ```

extension Expression where ExpressionValue: Numeric {
  /// Addition operator for numeric expressions.
  ///
  /// Example:
  /// ```swift
  /// let price = ColumnExpression<Double>("price")
  /// let tax = ColumnExpression<Double>("tax")
  /// let total = price + tax
  /// // Generates: (price + tax)
  /// ```
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side expression.
  ///   - rhs: The right-hand side expression.
  /// - Returns: A binary operation expression representing the addition.
  public static func + <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, ExpressionValue>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "+")
  }

  /// Subtraction operator for numeric expressions.
  ///
  /// Example:
  /// ```swift
  /// let price = ColumnExpression<Double>("price")
  /// let discount = ColumnExpression<Double>("discount")
  /// let total = price - discount
  /// // Generates: (price - discount)
  /// ```
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side expression.
  ///   - rhs: The right-hand side expression.
  /// - Returns: A binary operation expression representing the subtraction.
  public static func - <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, ExpressionValue>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "-")
  }

  /// Multiplication operator for numeric expressions.
  ///
  /// Example:
  /// ```swift
  /// let price = ColumnExpression<Double>("price")
  /// let quantity = ColumnExpression<Double>("quantity")
  /// let total = price * quantity
  /// // Generates: (price * quantity)
  /// ```
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side expression.
  ///   - rhs: The right-hand side expression.
  /// - Returns: A binary operation expression representing the multiplication.
  public static func * <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, ExpressionValue>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "*")
  }

  /// Division operator for numeric expressions.
  ///
  /// Example:
  /// ```swift
  /// let price = ColumnExpression<Double>("price")
  /// let divisor = ColumnExpression<Double>("divisor")
  /// let result = price / divisor
  /// // Generates: (price / divisor)
  /// ```
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side expression.
  ///   - rhs: The right-hand side expression.
  /// - Returns: A binary operation expression representing the division.
  public static func / <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, ExpressionValue>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "/")
  }
}

extension Expression where ExpressionValue: BinaryInteger {
  /// Modulo operator for integer expressions.
  ///
  /// Example:
  /// ```swift
  /// let value = ColumnExpression<Int>("value")
  /// let divisor = ColumnExpression<Int>("divisor")
  /// let result = value % divisor
  /// // Generates: (value % divisor)
  /// ```
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side expression.
  ///   - rhs: The right-hand side expression.
  /// - Returns: A binary operation expression representing the modulo operation.
  public static func % <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, ExpressionValue>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "%")
  }
}

extension Expression where ExpressionValue: SignedNumeric {
  /// Unary negation operator for signed numeric expressions.
  ///
  /// Example:
  /// ```swift
  /// let value = ColumnExpression<Int>("value")
  /// let negatedValue = -value
  /// // Generates: (-value)
  /// ```
  ///
  /// - Parameter operand: The expression to negate.
  /// - Returns: A unary operation expression representing the negation.
  public static prefix func - (operand: Self) -> UnaryOperation<Self, ExpressionValue> {
    UnaryOperation(operand: operand, sqlOperator: "-", isPrefix: true)
  }
}
