// MARK: - Arithmetic Operators

/// Arithmetic operators for numeric expressions.
///
/// Compose SQL arithmetic from typed column expressions and literals:
/// ```swift
/// let price = ColumnExpression<Double>("price")
/// let discount = ColumnExpression<Double>("discount")
/// let net = price - discount
/// // Renders: ( "price" - "discount" )
/// ```

extension Expression where ExpressionValue: Numeric {
  /// Adds two numeric expressions.
  ///
  /// ```swift
  /// let subtotal = ColumnExpression<Double>("subtotal")
  /// let tax = ColumnExpression<Double>("tax")
  /// let invoices = try await db.query(
  ///   sql: "SELECT \(subtotal + tax) AS total FROM \(raw: "invoices")",
  ///   step: { stmt, _ in Double.column(of: stmt, at: 0) }
  /// )
  /// ```
  public static func + <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, ExpressionValue>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "+")
  }

  /// Subtracts one numeric expression from another.
  ///
  /// ```swift
  /// let listPrice = ColumnExpression<Double>("list_price")
  /// let discount = ColumnExpression<Double>("discount")
  /// let net = listPrice - discount
  /// // Renders: ( "list_price" - "discount" )
  /// ```
  public static func - <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, ExpressionValue>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "-")
  }

  /// Multiplies two numeric expressions.
  ///
  /// ```swift
  /// let unitPrice = ColumnExpression<Double>("unit_price")
  /// let quantity = ColumnExpression<Double>("quantity")
  /// let lineTotal = unitPrice * quantity
  /// // Renders: ( "unit_price" * "quantity" )
  /// ```
  public static func * <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, ExpressionValue>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "*")
  }

  /// Divides one numeric expression by another.
  ///
  /// SQLite follows C semantics: dividing two integer expressions truncates,
  /// and division by zero yields `NULL`.
  ///
  /// ```swift
  /// let total = ColumnExpression<Double>("total")
  /// let count = ColumnExpression<Double>("count")
  /// let average = total / count
  /// // Renders: ( "total" / "count" )
  /// ```
  public static func / <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, ExpressionValue>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "/")
  }
}

extension Expression where ExpressionValue: BinaryInteger {
  /// Computes the remainder of integer division.
  ///
  /// Restricted to `BinaryInteger` because SQLite's `%` operator coerces both
  /// operands to integers; using it on floating-point columns silently truncates.
  ///
  /// ```swift
  /// let id = ColumnExpression<Int>("id")
  /// let isEven = (id % 2) == 0
  /// // Renders: ( ( "id" % ? ) = ? )
  /// ```
  public static func % <R: Expression>(lhs: Self, rhs: R) -> BinaryOperation<Self, R, ExpressionValue>
  where R.ExpressionValue == ExpressionValue {
    BinaryOperation(left: lhs, right: rhs, sqlOperator: "%")
  }
}

extension Expression where ExpressionValue: SignedNumeric {
  /// Negates a signed numeric expression.
  ///
  /// ```swift
  /// let balance = ColumnExpression<Double>("balance")
  /// let owed = -balance
  /// // Renders: ( - "balance" )
  /// ```
  public static prefix func - (operand: Self) -> UnaryOperation<Self, ExpressionValue> {
    UnaryOperation(operand: operand, sqlOperator: "-", isPrefix: true)
  }
}
