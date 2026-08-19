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
  /// Renders `<expr> IS NULL`, true when the expression evaluates to NULL.
  ///
  /// ```swift
  /// let email = ColumnExpression<String?>("email")
  /// let unverified = try await db.query(
  ///   "SELECT id FROM users WHERE \(email.isNull())"
  /// ) { stmt, _ in
  ///   try Int64.column(of: stmt, at: 0)
  /// }
  /// ```
  public func isNull() -> UnaryOperation<Self, Bool> {
    UnaryOperation(operand: self, sqlOperator: "IS NULL", isPrefix: false)
  }

  /// Renders `<expr> IS NOT NULL`, true when the expression evaluates to a non-NULL value.
  ///
  /// ```swift
  /// let deletedAt = ColumnExpression<Date?>("deleted_at")
  /// let activeIDs = try await db.query(
  ///   "SELECT id FROM users WHERE \(deletedAt.isNotNull())"
  /// ) { stmt, _ in
  ///   try Int64.column(of: stmt, at: 0)
  /// }
  /// ```
  public func isNotNull() -> UnaryOperation<Self, Bool> {
    UnaryOperation(operand: self, sqlOperator: "IS NOT NULL", isPrefix: false)
  }
}
