/// SQL function expression such as `COUNT(*)`, `SUM(price)`, or `UPPER(name)`.
///
/// Conforming types render as SQL function calls and participate in expression composition
/// like any other `Expression`. The protocol is a marker that distinguishes function-call
/// expressions from operators, literals, and column references.
///
/// ```swift
/// let total = Sum(ColumnExpression<Int>("price"))
/// let status = ColumnExpression<Int>("status")
/// let rows = try await db.query("SELECT \(total) FROM orders WHERE \(status == 1)") { stmt, _ in
///   try Int?.column(of: stmt, at: 0)
/// }
/// ```
public protocol Function<ExpressionValue>: Expression {}
