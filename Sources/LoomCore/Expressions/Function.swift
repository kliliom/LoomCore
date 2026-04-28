/// SQL function expression such as `COUNT(*)`, `SUM(price)`, or `UPPER(name)`.
///
/// Conforming types render as SQL function calls and participate in expression composition
/// like any other `Expression`. The protocol is a marker that distinguishes function-call
/// expressions from operators, literals, and column references.
///
/// ```swift
/// let total = Sum(ColumnExpression<Int>("price"))
/// let rows = try await db.query("SELECT \(total) FROM orders WHERE \(ColumnExpression<Int>("status") == 1)")
/// ```
public protocol Function<ExpressionValue>: Expression {}
