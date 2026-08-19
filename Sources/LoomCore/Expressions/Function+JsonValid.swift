/// SQL `JSON_VALID()` — whether a value parses as well-formed JSON.
///
/// The result is `Bool?` because `JSON_VALID(NULL)` is NULL.
///
/// ```swift
/// let data = ColumnExpression<String>("data")
/// let broken = try await db.query("SELECT id FROM events WHERE \(data.jsonValid() == false)") { stmt, _ in
///   try Int64.column(of: stmt, at: 0)
/// }
/// ```
///
/// Generates SQL of the form `JSON_VALID("data")`. The one-argument form accepts only JSON
/// *text* — it reports the binary JSONB encoding as invalid. Validate JSONB columns with
/// ``Expression/jsonValid(_:)`` and ``Flags-swift.struct``.
public struct JSONValid: Function {
  public typealias ExpressionValue = Bool?

  /// Which encodings `JSON_VALID` accepts, as SQLite's second-argument bitmask.
  ///
  /// Requires SQLite 3.45+, which ships with the same OS versions as the `jsonb` APIs.
  /// Combine as needed; `[.json, .jsonb]` covers a column migrated between text and
  /// binary storage.
  public struct Flags: OptionSet, Sendable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    /// JSON text strictly conforming to RFC 8259.
    public static let json = Flags(rawValue: 1)

    /// JSON text with JSON5 extensions.
    public static let json5 = Flags(rawValue: 2)

    /// A BLOB that superficially appears to be JSONB.
    public static let probablyJSONB = Flags(rawValue: 4)

    /// A BLOB strictly conforming to SQLite's internal JSONB format.
    public static let jsonb = Flags(rawValue: 8)
  }

  let expression: any Expression

  // nil renders the one-argument form; SQLite rejects a flags value outside 1...15.
  let flags: Flags?

  init(_ expression: any Expression) {
    self.expression = expression
    self.flags = nil
  }

  // SQLite rejects a flags value outside 1...15; the empty set is unrepresentable there.
  init(_ expression: any Expression, flags: Flags) {
    precondition(!flags.isEmpty, "JSON_VALID flags must name at least one encoding")
    self.expression = expression
    self.flags = flags
  }

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("JSON_VALID(")
    expression.append(to: &builder)
    if let flags {
      builder.appendLiteral(", \(flags.rawValue)")
    }
    builder.appendLiteral(")")
  }
}

extension Expression {
  /// Tests this expression for well-formed JSON text via SQL `JSON_VALID()`.
  ///
  /// ```swift
  /// let data = ColumnExpression<String>("data")
  /// let isValid = data.jsonValid()
  /// // SQL: JSON_VALID("data")
  /// ```
  ///
  /// This form accepts only JSON *text*: it reports the binary JSONB encoding — including
  /// blobs this library writes via ``jsonb()`` and friends — as invalid. Use
  /// ``jsonValid(_:)`` for JSONB or mixed-storage columns.
  public func jsonValid() -> JSONValid {
    JSONValid(self)
  }

  /// Tests this expression against the given encodings via SQL `JSON_VALID(X, Y)`.
  ///
  /// ```swift
  /// let data = ColumnExpression<Data>("data")
  /// if #available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
  ///   let isValid = data.jsonValid([.json, .jsonb])
  ///   // SQL: JSON_VALID("data", 9)
  /// }
  /// ```
  ///
  /// Requires SQLite 3.45+, which ships with the annotated OS versions.
  ///
  /// - Parameter flags: Accepted encodings; must be non-empty.
  @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  public func jsonValid(_ flags: JSONValid.Flags) -> JSONValid {
    JSONValid(self, flags: flags)
  }
}
