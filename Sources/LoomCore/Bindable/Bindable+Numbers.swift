import Foundation
import SQLite3

extension Int: Bindable {
  public static func bind(to stmt: borrowing StatementHandle, value: Int, at index: Int32) throws {
    try Int64.bind(to: stmt, value: Int64(value), at: index)
  }

  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Int {
    try Int(Int64.column(of: stmt, at: index))
  }

  public func asSQLLiteral() throws -> String {
    "\(self)"
  }

  public static var defaultSQLStorageType: String { "INTEGER" }
}

extension Int32: Bindable {
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try check(sqlite3_bind_int(stmt.stmtPtr, index, value), db: stmt.dbPtr, is: SQLITE_OK)
  }

  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    sqlite3_column_int(stmt.stmtPtr, index)
  }

  public func asSQLLiteral() throws -> String {
    "\(self)"
  }

  public static var defaultSQLStorageType: String { "INTEGER" }
}

extension Int64: Bindable {
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try check(sqlite3_bind_int64(stmt.stmtPtr, index, value), db: stmt.dbPtr, is: SQLITE_OK)
  }

  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    sqlite3_column_int64(stmt.stmtPtr, index)
  }

  public func asSQLLiteral() throws -> String {
    "\(self)"
  }

  public static var defaultSQLStorageType: String { "INTEGER" }
}

extension Bool: Bindable {
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try Int.bind(to: stmt, value: value ? 1 : 0, at: index)
  }

  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    try Int.column(of: stmt, at: index) != 0
  }

  public func asSQLLiteral() throws -> String {
    "\(self ? "TRUE" : "FALSE")"
  }

  public static var defaultSQLStorageType: String { "BOOLEAN" }
}

extension Float: Bindable {
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try check(sqlite3_bind_double(stmt.stmtPtr, index, Double(value)), db: stmt.dbPtr, is: SQLITE_OK)
  }

  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    Float(sqlite3_column_double(stmt.stmtPtr, index))
  }

  public func asSQLLiteral() throws -> String {
    "\(self)"
  }

  public static var defaultSQLStorageType: String { "DOUBLE" }
}

extension Double: Bindable {
  public static func bind(to stmt: borrowing StatementHandle, value: Self, at index: Int32) throws {
    try check(sqlite3_bind_double(stmt.stmtPtr, index, value), db: stmt.dbPtr, is: SQLITE_OK)
  }

  public static func column(of stmt: borrowing StatementHandle, at index: Int32) throws -> Self {
    sqlite3_column_double(stmt.stmtPtr, index)
  }

  public func asSQLLiteral() throws -> String {
    "\(self)"
  }

  public static var defaultSQLStorageType: String { "DOUBLE" }
}
