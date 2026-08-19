extension String {
  /// Doubles every occurrence of `quote`, matching at the Unicode-scalar level.
  ///
  /// Grapheme-level search (`replacingOccurrences(of:with:)` without `.literal`) treats a
  /// quote followed by a combining scalar as a single character and never finds the quote,
  /// letting it reach the rendered SQL undoubled and terminate the literal or identifier
  /// early. SQLite's lexer operates on bytes, so escaping must too.
  func doublingOccurrences(of quote: Unicode.Scalar) -> String {
    guard unicodeScalars.contains(quote) else { return self }
    var scalars = String.UnicodeScalarView()
    scalars.reserveCapacity(unicodeScalars.count + 1)
    for scalar in unicodeScalars {
      scalars.append(scalar)
      if scalar == quote {
        scalars.append(scalar)
      }
    }
    return String(scalars)
  }
}
