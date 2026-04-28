import Foundation
import SQLite3

extension Int: Bindable {
  /// Binds the value as an `INTEGER` parameter, forwarding to `Int64` for platform-independent storage.
  public static func bind(to stmt: borrowing StatementHandle, value: Int, at index: Int32) throws {
    try Int64.bind(to: stmt, value: Int64(value), at: index)
  }

  /// Reads the column as an `Int64` and narrows it to `Int`.
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Int {
    try Int(Int64.column(of: stmt, at: index))
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

  /// Reads the column via `sqlite3_column_int`. Values outside the `Int32` range are truncated by SQLite.
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    sqlite3_column_int(stmt.stmtPtr, index)
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

  /// Reads the column via `sqlite3_column_int64`.
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    sqlite3_column_int64(stmt.stmtPtr, index)
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

  /// Reads the column as an integer; any non-zero value is treated as `true`.
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    try Int.column(of: stmt, at: index) != 0
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

  /// Reads the column as a `Double` and narrows it to `Float`. Round-tripping may lose precision.
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    Float(sqlite3_column_double(stmt.stmtPtr, index))
  }

  /// Renders the value using Swift's default floating-point description.
  public func asSQLLiteral() throws -> String {
    "\(self)"
  }

  /// SQLite storage type for `Float` columns: `DOUBLE`.
  public static var defaultSQLStorageType: String { "DOUBLE" }
}

extension Double: Bindable {
  /// Binds the value as a `REAL` parameter via `sqlite3_bind_double`.
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try check(sqlite3_bind_double(stmt.stmtPtr, index, value), db: stmt.dbPtr, is: SQLITE_OK)
  }

  /// Reads the column via `sqlite3_column_double`.
  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    sqlite3_column_double(stmt.stmtPtr, index)
  }

  /// Renders the value using Swift's default floating-point description.
  public func asSQLLiteral() throws -> String {
    "\(self)"
  }

  /// SQLite storage type for `Double` columns: `DOUBLE`.
  public static var defaultSQLStorageType: String { "DOUBLE" }
}
