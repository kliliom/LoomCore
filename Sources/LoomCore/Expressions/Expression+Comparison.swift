// MARK: - Comparison Operators

/// Comparison operators for expressions.
///
/// Build SQL predicates using the standard Swift comparison operators against any `Expression`
/// whose value type is `Equatable` or `Comparable`. The right-hand side may be another column,
/// a literal, or any other expression sharing the same value type.
///
/// ```swift
/// let price = ColumnExpression<Int>("price")
/// let cost = ColumnExpression<Int>("cost")
/// let rows = try await db.query("SELECT id FROM products WHERE \(price >= 1000) AND \(price > cost)") { stmt, _ in
///   try Int64.column(of: stmt, at: 0)
/// }
/// ```

extension Expression where ExpressionValue: Equatable {
  /// Builds a SQL `=` predicate between two expressions of the same value type.
  ///
  /// ```swift
  /// let status = ColumnExpression<String>("status")
  /// let active = try await db.query("SELECT id FROM orders WHERE \(status == "active")") { stmt, _ in
  ///   try Int64.column(of: stmt, at: 0)
  /// }
  /// ```
  public static func == <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "=")
  }

  /// Builds a SQL `<>` predicate between two expressions of the same value type.
  ///
  /// ```swift
  /// let status = ColumnExpression<String>("status")
  /// let nonArchived = try await db.query("SELECT id FROM orders WHERE \(status != "archived")") { stmt, _ in
  ///   try Int64.column(of: stmt, at: 0)
  /// }
  /// ```
  public static func != <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "<>")
  }
}

extension Expression where ExpressionValue: Comparable {
  /// Builds a SQL `<` predicate between two expressions of the same value type.
  ///
  /// ```swift
  /// let stock = ColumnExpression<Int>("stock")
  /// let lowStock = try await db.query("SELECT id FROM products WHERE \(stock < 10)") { stmt, _ in
  ///   try Int64.column(of: stmt, at: 0)
  /// }
  /// ```
  public static func < <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "<")
  }

  /// Builds a SQL `>` predicate between two expressions of the same value type.
  ///
  /// ```swift
  /// let age = ColumnExpression<Int>("age")
  /// let adults = try await db.query("SELECT id FROM users WHERE \(age > 17)") { stmt, _ in
  ///   try Int64.column(of: stmt, at: 0)
  /// }
  /// ```
  public static func > <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: ">")
  }

  /// Builds a SQL `<=` predicate between two expressions of the same value type.
  ///
  /// ```swift
  /// let price = ColumnExpression<Int>("price")
  /// let affordable = try await db.query("SELECT id FROM products WHERE \(price <= 5000)") { stmt, _ in
  ///   try Int64.column(of: stmt, at: 0)
  /// }
  /// ```
  public static func <= <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "<=")
  }

  /// Builds a SQL `>=` predicate between two expressions of the same value type.
  ///
  /// ```swift
  /// let score = ColumnExpression<Int>("score")
  /// let passing = try await db.query("SELECT id FROM exams WHERE \(score >= 60)") { stmt, _ in
  ///   try Int64.column(of: stmt, at: 0)
  /// }
  /// ```
  public static func >= <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: ">=")
  }
}
