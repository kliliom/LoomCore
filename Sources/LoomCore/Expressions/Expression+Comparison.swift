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
/// let rows = try database.query("SELECT * FROM products WHERE \(price >= 1000) AND \(price > cost)")
/// ```

extension Expression where ExpressionValue: Equatable {
  /// Builds a SQL `=` predicate between two expressions of the same value type.
  ///
  /// ```swift
  /// let status = ColumnExpression<String>("status")
  /// let active = try database.query("SELECT * FROM orders WHERE \(status == "active")")
  /// ```
  public static func == <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "=")
  }

  /// Builds a SQL `<>` predicate between two expressions of the same value type.
  ///
  /// ```swift
  /// let status = ColumnExpression<String>("status")
  /// let nonArchived = try database.query("SELECT * FROM orders WHERE \(status != "archived")")
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
  /// let lowStock = try database.query("SELECT * FROM products WHERE \(stock < 10)")
  /// ```
  public static func < <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "<")
  }

  /// Builds a SQL `>` predicate between two expressions of the same value type.
  ///
  /// ```swift
  /// let age = ColumnExpression<Int>("age")
  /// let adults = try database.query("SELECT * FROM users WHERE \(age > 17)")
  /// ```
  public static func > <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: ">")
  }

  /// Builds a SQL `<=` predicate between two expressions of the same value type.
  ///
  /// ```swift
  /// let price = ColumnExpression<Int>("price")
  /// let affordable = try database.query("SELECT * FROM products WHERE \(price <= 5000)")
  /// ```
  public static func <= <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "<=")
  }

  /// Builds a SQL `>=` predicate between two expressions of the same value type.
  ///
  /// ```swift
  /// let score = ColumnExpression<Int>("score")
  /// let passing = try database.query("SELECT * FROM exams WHERE \(score >= 60)")
  /// ```
  public static func >= <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, Bool>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: ">=")
  }
}
