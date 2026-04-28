/// SQL `INSTR()` function returning the 1-based position of a substring within a string.
///
/// Returns 0 when the substring is not found, or `nil` when either operand is NULL.
///
/// ```swift
/// let title = ColumnExpression<String>("title")
/// let position = title.locate("Swift")
/// let rows = try await db.query(
///   "SELECT \(title), \(position) FROM \(raw: "articles") WHERE \(position) > 0"
/// )
/// ```
///
/// Renders as `INSTR("title", ?)`.
public struct Locate: Function {
  public typealias ExpressionValue = Int?

  let needle: any Expression

  let haystack: any Expression

  /// Creates a locate function searching for `needle` inside `haystack`.
  public init(needle: any Expression, in haystack: any Expression) {
    self.needle = needle
    self.haystack = haystack
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("INSTR(")
    haystack.append(to: &builder)
    builder.appendLiteral(", ")
    needle.append(to: &builder)
    builder.appendLiteral(")")
  }
}

extension Expression where ExpressionValue == String {
  /// Locates the 1-based position of `needle` within this string expression.
  ///
  /// ```swift
  /// let email = ColumnExpression<String>("email")
  /// let atSign = email.locate("@")
  /// let rows = try await db.query(
  ///   "SELECT \(email) FROM \(raw: "users") WHERE \(atSign) > 0"
  /// )
  /// ```
  ///
  /// - Returns: `Locate` yielding the 1-based index, 0 when absent, or `nil` when either side is NULL.
  public func locate(_ needle: any Expression<String>) -> Locate {
    Locate(needle: needle, in: self)
  }
}
