// MARK: - NULL Check Operators

/// NULL checking operators for expressions.
///
/// These methods enable checking for NULL values in SQL expressions.
///
/// Example:
/// ```swift
/// let optionalAge = ColumnExpression<Int?>("age")
/// let condition = optionalAge.isNull()
/// // Generates: (age IS NULL)
/// ```

// MARK: - Expression Extension

extension Expression {
  /// Checks if the expression evaluates to NULL.
  ///
  /// This generates a SQL IS NULL check.
  ///
  /// Example:
  /// ```swift
  /// let optionalAge = ColumnExpression<Int?>("age")
  /// let condition = optionalAge.isNull()
  /// // Generates: (age IS NULL)
  /// ```
  ///
  /// - Returns: A boolean expression that is true when the value is NULL.
  public func isNull() -> UnaryOperation<Self, Bool> {
    UnaryOperation(operand: self, sqlOperator: "IS NULL", isPrefix: false)
  }

  /// Checks if the expression does not evaluate to NULL.
  ///
  /// This generates a SQL IS NOT NULL check.
  ///
  /// Example:
  /// ```swift
  /// let optionalAge = ColumnExpression<Int?>("age")
  /// let condition = optionalAge.isNotNull()
  /// // Generates: (age IS NOT NULL)
  /// ```
  ///
  /// - Returns: A boolean expression that is true when the value is not NULL.
  public func isNotNull() -> UnaryOperation<Self, Bool> {
    UnaryOperation(operand: self, sqlOperator: "IS NOT NULL", isPrefix: false)
  }
}
