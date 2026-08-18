import Foundation
import SQLite3

extension Int: Bindable {
  /// Binds the value as an `INTEGER` parameter, forwarding to `Int64` for platform-independent storage.
  public static func bind(to stmt: borrowing StatementHandle, value: Int, at index: Int32) throws {
    try Int64.bind(to: stmt, value: Int64(value), at: index)
  }

  /// Reads the column as an `INTEGER` and narrows it to `Int`.
  ///
  /// Throws `LoomError.core(.nullValue, …)` when the column is `NULL` — use `Int?` for nullable
  /// columns — and `LoomError.core(.typeMappingFailed, …)` when the storage class is not `INTEGER`
  /// or the value does not fit in `Int`.
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Int {
    _ = try requireStorageClass(of: stmt, at: index, oneOf: .integer, for: Self.self)
    let wide = sqlite3_column_int64(stmt.stmtPtr, index)
    guard let value = Int(exactly: wide) else {
      throw LoomError.core(
        .typeMappingFailed,
        message: "Column at index \(index) holds \(wide), which is out of range for Int."
      )
    }
    return value
  }

  /// Renders the value as a base-10 integer literal.
  ///
  /// ```swift
  /// try 42.asSQLLiteral()  // "42"
  /// ```
  public func asSQLLiteral() throws -> String {
    "\(self)"
  }

  /// SQLite storage type for `Int` columns: `INTEGER`.
  public static var defaultSQLStorageType: String { "INTEGER" }
}

extension Int32: Bindable {
  /// Binds the value as a 32-bit `INTEGER` parameter via `sqlite3_bind_int`.
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try check(sqlite3_bind_int(stmt.stmtPtr, index, value), db: stmt.dbPtr, is: SQLITE_OK)
  }

  /// Reads the column as an `INTEGER` and narrows it to `Int32`.
  ///
  /// Throws `LoomError.core(.nullValue, …)` when the column is `NULL` — use `Int32?` for nullable
  /// columns — and `LoomError.core(.typeMappingFailed, …)` when the storage class is not `INTEGER`
  /// or the value does not fit in `Int32`.
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    _ = try requireStorageClass(of: stmt, at: index, oneOf: .integer, for: Self.self)
    let wide = sqlite3_column_int64(stmt.stmtPtr, index)
    guard let value = Int32(exactly: wide) else {
      throw LoomError.core(
        .typeMappingFailed,
        message: "Column at index \(index) holds \(wide), which is out of range for Int32."
      )
    }
    return value
  }

  /// Renders the value as a base-10 integer literal.
  public func asSQLLiteral() throws -> String {
    "\(self)"
  }

  /// SQLite storage type for `Int32` columns: `INTEGER`.
  public static var defaultSQLStorageType: String { "INTEGER" }
}

extension Int64: Bindable {
  /// Binds the value as a 64-bit `INTEGER` parameter via `sqlite3_bind_int64`. Matches SQLite's native integer width.
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try check(sqlite3_bind_int64(stmt.stmtPtr, index, value), db: stmt.dbPtr, is: SQLITE_OK)
  }

  /// Reads the column as an `INTEGER` via `sqlite3_column_int64`.
  ///
  /// Throws `LoomError.core(.nullValue, …)` when the column is `NULL` — use `Int64?` for nullable
  /// columns — and `LoomError.core(.typeMappingFailed, …)` when the storage class is not `INTEGER`.
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    _ = try requireStorageClass(of: stmt, at: index, oneOf: .integer, for: Self.self)
    return sqlite3_column_int64(stmt.stmtPtr, index)
  }

  /// Renders the value as a base-10 integer literal.
  public func asSQLLiteral() throws -> String {
    "\(self)"
  }

  /// SQLite storage type for `Int64` columns: `INTEGER`.
  public static var defaultSQLStorageType: String { "INTEGER" }
}

extension Bool: Bindable {
  /// Binds the value as `1` (true) or `0` (false) in an `INTEGER` parameter.
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try Int.bind(to: stmt, value: value ? 1 : 0, at: index)
  }

  /// Reads the column as an `INTEGER`; any non-zero value is treated as `true`.
  ///
  /// Throws `LoomError.core(.nullValue, …)` when the column is `NULL` — use `Bool?` for nullable
  /// columns — and `LoomError.core(.typeMappingFailed, …)` when the storage class is not `INTEGER`.
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    _ = try requireStorageClass(of: stmt, at: index, oneOf: .integer, for: Self.self)
    return sqlite3_column_int64(stmt.stmtPtr, index) != 0
  }

  /// Renders the value as `TRUE` or `FALSE`, which SQLite recognizes as `1` and `0`.
  ///
  /// ```swift
  /// try true.asSQLLiteral()   // "TRUE"
  /// try false.asSQLLiteral()  // "FALSE"
  /// ```
  public func asSQLLiteral() throws -> String {
    "\(self ? "TRUE" : "FALSE")"
  }

  /// SQLite storage type for `Bool` columns: `BOOLEAN`. SQLite treats this as `INTEGER` affinity at runtime.
  public static var defaultSQLStorageType: String { "BOOLEAN" }
}

extension Float: Bindable {
  /// Binds the value as a `REAL` parameter, widened to `Double` for SQLite's native floating-point width.
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try check(sqlite3_bind_double(stmt.stmtPtr, index, Double(value)), db: stmt.dbPtr, is: SQLITE_OK)
  }

  /// Reads the column as a `REAL` (or `INTEGER`) and narrows it to `Float`. Round-tripping may lose precision.
  ///
  /// Throws `LoomError.core(.nullValue, …)` when the column is `NULL` — use `Float?` for nullable
  /// columns — and `LoomError.core(.typeMappingFailed, …)` for `TEXT` or `BLOB` storage or a finite
  /// value whose magnitude exceeds the `Float` range. Stored infinities read back as infinities.
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    _ = try requireStorageClass(of: stmt, at: index, oneOf: [.real, .integer], for: Self.self)
    let wide = sqlite3_column_double(stmt.stmtPtr, index)
    let value = Float(wide)
    guard value.isFinite || !wide.isFinite else {
      throw LoomError.core(
        .typeMappingFailed,
        message: "Column at index \(index) holds \(wide), which is out of range for Float."
      )
    }
    return value
  }

  /// Renders the value using Swift's default floating-point description.
  ///
  /// SQLite has no literal syntax for non-finite values, so infinities render as `9.0e999` /
  /// `-9.0e999` (which SQLite parses back to ±infinity) and NaN renders as `NULL` — the same
  /// value `sqlite3_bind_double` stores for NaN.
  public func asSQLLiteral() throws -> String {
    if isNaN { return "NULL" }
    if isInfinite { return self > 0 ? "9.0e999" : "-9.0e999" }
    return "\(self)"
  }

  /// SQLite storage type for `Float` columns: `DOUBLE`.
  public static var defaultSQLStorageType: String { "DOUBLE" }
}

extension Double: Bindable {
  /// Binds the value as a `REAL` parameter via `sqlite3_bind_double`.
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try check(sqlite3_bind_double(stmt.stmtPtr, index, value), db: stmt.dbPtr, is: SQLITE_OK)
  }

  /// Reads the column as a `REAL` (or `INTEGER`, widened) via `sqlite3_column_double`.
  ///
  /// Throws `LoomError.core(.nullValue, …)` when the column is `NULL` — use `Double?` for nullable
  /// columns — and `LoomError.core(.typeMappingFailed, …)` for `TEXT` or `BLOB` storage.
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    _ = try requireStorageClass(of: stmt, at: index, oneOf: [.real, .integer], for: Self.self)
    return sqlite3_column_double(stmt.stmtPtr, index)
  }

  /// Renders the value using Swift's default floating-point description.
  ///
  /// SQLite has no literal syntax for non-finite values, so infinities render as `9.0e999` /
  /// `-9.0e999` (which SQLite parses back to ±infinity) and NaN renders as `NULL` — the same
  /// value `sqlite3_bind_double` stores for NaN.
  public func asSQLLiteral() throws -> String {
    if isNaN { return "NULL" }
    if isInfinite { return self > 0 ? "9.0e999" : "-9.0e999" }
    return "\(self)"
  }

  /// SQLite storage type for `Double` columns: `DOUBLE`.
  public static var defaultSQLStorageType: String { "DOUBLE" }
}
