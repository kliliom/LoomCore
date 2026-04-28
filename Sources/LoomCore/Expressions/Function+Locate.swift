/// An SQL function that finds the position of a substring within a string.
///
/// This function generates SQL's `INSTR()` function, which returns the 1-based position
/// of the first occurrence of a substring (needle) within a string (haystack). Returns 0
/// if the substring is not found, or `nil` if either the haystack or needle is NULL.
///
/// Example SQL output: `INSTR(haystack, needle)`
public struct Locate: Function {
  public typealias ExpressionValue = Int?

  /// The substring to search for.
  let needle: any Expression

  /// The string to search in.
  let haystack: any Expression

  /// Creates a new locate function.
  ///
  /// - Parameters:
  ///   - needle: The substring to search for.
  ///   - haystack: The string to search in.
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

extension Expression {
  /// Finds the position of a substring within this expression.
  ///
  /// - Parameter needle: The substring to search for.
  /// - Returns: A `Locate` function that returns the 1-based position, 0 if not found, or `nil` if either value is NULL.
  public func locate(_ needle: any Expression<ExpressionValue>) -> Locate {
    Locate(needle: needle, in: self)
  }
}
