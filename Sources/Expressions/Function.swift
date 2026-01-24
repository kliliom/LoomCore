/// A protocol representing an SQL function expression.
///
/// Functions are a specialized type of expression that represent SQL function calls
/// such as `COUNT()`, `SUM()`, `UPPER()`, etc. This protocol inherits from `Expression`
/// and serves as a marker protocol to distinguish function expressions from other types
/// of expressions.
public protocol Function<ExpressionValue>: Expression {}
