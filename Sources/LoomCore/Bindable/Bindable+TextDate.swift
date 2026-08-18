import Foundation
import SQLite3

/// Date stored as SQLite datetime `TEXT` instead of `Date`'s epoch-seconds `REAL`.
///
/// Binding writes `YYYY-MM-DD HH:MM:SS.SSS` in UTC, so stored values compare and sort correctly
/// against `CURRENT_TIMESTAMP` output and work with SQLite's `date()`/`datetime()`/`strftime()`
/// functions. Use it for columns declared with TEXT affinity; use plain `Date` for `DOUBLE`
/// columns.
///
/// ```swift
/// try await db.exec("CREATE TABLE events (name TEXT, created_at TEXT DEFAULT CURRENT_TIMESTAMP)")
/// try await db.exec("INSERT INTO events (name, created_at) VALUES (\("deploy"), \(TextDate(Date())))")
///
/// let recent = try await db.query(
///   "SELECT name FROM events WHERE created_at > \(TextDate(cutoff))"
/// ) { stmt, _ in
///   try String.column(of: stmt, at: 0)
/// }
/// ```
public struct TextDate: Bindable, Hashable {
  /// Moment in time this value represents.
  public var date: Date

  /// Creates a text-stored date wrapping `date`.
  public init(_ date: Date) {
    self.date = date
  }

  /// Binds the date as a `TEXT` parameter holding `YYYY-MM-DD HH:MM:SS.SSS` in UTC.
  ///
  /// Sub-millisecond precision is truncated — SQLite's own subsecond datetime output carries
  /// three fractional digits, and matching it keeps stored values uniformly comparable.
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try String.bind(to: stmt, value: SQLiteDateText.render(value.date), at: index)
  }

  /// Reads the column as SQLite datetime text and reconstructs a `TextDate`.
  ///
  /// Accepts `YYYY-MM-DD HH:MM:SS` with optional fractional seconds, `T` separator, and
  /// `Z`/`±HH:MM` offset; text without an offset is read as UTC. Throws
  /// `LoomError.core(.nullValue, …)` when the column is `NULL` — use `TextDate?` for nullable
  /// columns — and `LoomError.core(.typeMappingFailed, …)` for any non-`TEXT` storage class or
  /// unparseable text.
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    _ = try requireStorageClass(of: stmt, at: index, oneOf: .text, for: Self.self)
    let text = try String.column(of: stmt, at: index)
    guard let date = SQLiteDateText.parse(text) else {
      throw LoomError.core(
        .typeMappingFailed,
        message:
          "Column at index \(index) holds \"\(text)\", which is not a recognized datetime, cannot return TextDate."
      )
    }
    return TextDate(date)
  }

  /// Renders the date as a single-quoted datetime string literal, such as `'2026-08-15 09:30:00.500'`.
  public func asSQLLiteral() throws -> String {
    try SQLiteDateText.render(date).asSQLLiteral()
  }

  /// SQLite storage type for `TextDate` columns: `TEXT`.
  public static var defaultSQLStorageType: String { "TEXT" }
}

extension TextDate: Comparable {
  /// Orders text-stored dates by their underlying `Date`.
  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.date < rhs.date
  }
}

extension TextDate: Codable {
  /// Decodes the wrapped `Date` as a single value, honoring the decoder's date strategy.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(try container.decode(Date.self))
  }

  /// Encodes the wrapped `Date` as a single value, honoring the encoder's date strategy.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(date)
  }
}

extension Date {
  /// The date as a `TextDate`, for binding into columns that store SQLite datetime `TEXT`.
  ///
  /// ```swift
  /// try await db.exec("INSERT INTO events (created_at) VALUES (\(Date().textDate))")
  /// ```
  public var textDate: TextDate {
    TextDate(self)
  }
}

/// Parser and renderer for SQLite's datetime text formats (`YYYY-MM-DD HH:MM:SS`, optional
/// fractional seconds, `T` separator, and `Z`/`±HH:MM` offset; date-only reads as midnight;
/// `HH:MM` reads as `HH:MM:00`; no offset means UTC). Backs `TextDate` in both directions.
/// Parsing accepts a slight superset of SQLite's grammar — `ISO8601DateFormatter` tolerates
/// forms such as `24:00:00` (next-day midnight) and single-digit fields — which is harmless
/// for a reader.
@DatabaseActor
enum SQLiteDateText {
  /// Renders the date as `YYYY-MM-DD HH:MM:SS.SSS` in UTC — lexicographically comparable with
  /// `CURRENT_TIMESTAMP` output and accepted by SQLite's datetime functions. Sub-millisecond
  /// digits are truncated.
  nonisolated static func render(_ date: Date) -> String {
    date.ISO8601Format(
      Date.ISO8601FormatStyle(timeZone: .gmt)
        .year().month().day()
        .dateTimeSeparator(.space)
        .time(includingFractionalSeconds: true)
    )
  }

  static let withFractionalSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  static let withoutFractionalSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  static func parse(_ text: String) -> Date? {
    var normalized = text.replacingOccurrences(of: " ", with: "T")
    guard let separator = normalized.firstIndex(of: "T") else {
      normalized += "T00:00:00Z"
      return withoutFractionalSeconds.date(from: normalized)
    }
    let timeStart = normalized.index(after: separator)
    let offsetStart =
      normalized[timeStart...].firstIndex { $0 == "Z" || $0 == "+" || $0 == "-" } ?? normalized.endIndex
    let hasOffset = offsetStart != normalized.endIndex
    if normalized[timeStart..<offsetStart].lazy.filter({ $0 == ":" }).count == 1 {
      normalized.insert(contentsOf: ":00", at: offsetStart)
    }
    if !hasOffset {
      normalized += "Z"
    }
    // ISO8601DateFormatter's handling of >3 fractional digits varies by OS version; trim here so
    // the documented truncation to milliseconds holds everywhere.
    if let dot = normalized.firstIndex(of: ".") {
      let fractionStart = normalized.index(after: dot)
      let fractionEnd =
        normalized[fractionStart...].firstIndex { !("0"..."9").contains($0) } ?? normalized.endIndex
      if normalized.distance(from: fractionStart, to: fractionEnd) > 3 {
        normalized.removeSubrange(normalized.index(fractionStart, offsetBy: 3)..<fractionEnd)
      }
    }
    return withFractionalSeconds.date(from: normalized) ?? withoutFractionalSeconds.date(from: normalized)
  }
}
