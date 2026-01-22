import Foundation
import Testing

@testable import LoomCore

@Suite("Numeric Bindable Tests")
@DatabaseActor
struct BindableNumbersTests {
  @Test("Int binding and extraction")
  func testIntBinding() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    let testValue = 42
    try db.exec("INSERT INTO test (value) VALUES (\(testValue))")

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == testValue)
  }

  @Test("Int32 binding and extraction")
  func testInt32Binding() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    let testValue: Int32 = 12345
    try db.exec("INSERT INTO test (value) VALUES (\(testValue))")

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try Int32.column(of: stmt, at: 0)
    }

    #expect(result.first == testValue)
  }

  @Test("Int64 binding and extraction")
  func testInt64Binding() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    let testValue: Int64 = 9_223_372_036_854_775_807
    try db.exec("INSERT INTO test (value) VALUES (\(testValue))")

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try Int64.column(of: stmt, at: 0)
    }

    #expect(result.first == testValue)
  }

  @Test("Negative numbers")
  func testNegativeNumbers() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")
    let negativeValue = -123
    try db.exec("INSERT INTO test (value) VALUES (\(negativeValue))")

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == -123)
  }

  @Test("Bool binding and extraction")
  func testBoolBinding() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value BOOLEAN)")

    let trueValue = true
    try db.exec("INSERT INTO test (value) VALUES (\(trueValue))")

    let resultTrue = try db.query("SELECT value FROM test") { stmt, _ in
      try Bool.column(of: stmt, at: 0)
    }
    #expect(resultTrue.first == true)

    try db.exec("DELETE FROM test")
    let falseValue = false
    try db.exec("INSERT INTO test (value) VALUES (\(falseValue))")

    let resultFalse = try db.query("SELECT value FROM test") { stmt, _ in
      try Bool.column(of: stmt, at: 0)
    }
    #expect(resultFalse.first == false)
  }

  @Test("Float binding and extraction")
  func testFloatBinding() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value DOUBLE)")

    let testValue: Float = 3.14159
    try db.exec("INSERT INTO test (value) VALUES (\(testValue))")

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try Float.column(of: stmt, at: 0)
    }

    #expect(result.first != nil)
    #expect(abs(result.first! - testValue) < 0.00001)
  }

  @Test("Double binding and extraction")
  func testDoubleBinding() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value DOUBLE)")

    let testValue: Double = 2.718281828459045
    try db.exec("INSERT INTO test (value) VALUES (\(testValue))")

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try Double.column(of: stmt, at: 0)
    }

    #expect(result.first == testValue)
  }

  @Test("SQL literals for numbers")
  func testSQLLiterals() throws {
    #expect(try 42.asSQLLiteral() == "42")
    #expect(try Int32(123).asSQLLiteral() == "123")
    #expect(try Int64(-456).asSQLLiteral() == "-456")
    #expect(try true.asSQLLiteral() == "TRUE")
    #expect(try false.asSQLLiteral() == "FALSE")
    #expect(try Float(3.14).asSQLLiteral() == "3.14")
    #expect(try 3.14.asSQLLiteral() == "3.14")
  }

  @Test("Default SQL storage types")
  func testDefaultSQLStorageTypes() {
    #expect(Int.defaultSQLStorageType == "INTEGER")
    #expect(Int32.defaultSQLStorageType == "INTEGER")
    #expect(Int64.defaultSQLStorageType == "INTEGER")
    #expect(Bool.defaultSQLStorageType == "BOOLEAN")
    #expect(Float.defaultSQLStorageType == "DOUBLE")
    #expect(Double.defaultSQLStorageType == "DOUBLE")
  }

  @Test("Zero values")
  func testZeroValues() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (int_val INTEGER, double_val DOUBLE)")
    let intVal = 0
    let doubleVal = 0.0
    try db.exec("INSERT INTO test (int_val, double_val) VALUES (\(intVal), \(doubleVal))")

    let result = try db.query("SELECT int_val, double_val FROM test") { stmt, _ in
      let intResult = try Int.column(of: stmt, at: 0)
      let doubleResult = try Double.column(of: stmt, at: 1)
      return (intResult, doubleResult)
    }

    #expect(result.first?.0 == 0)
    #expect(result.first?.1 == 0.0)
  }

  @Test("Multiple numeric values")
  func testMultipleNumericValues() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    let values = [1, 2, 3, 42, 100]
    for val in values {
      try db.exec("INSERT INTO test (value) VALUES (\(val))")
    }

    let result = try db.query("SELECT value FROM test ORDER BY rowid") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.count == 5)
    #expect(result == values)
  }
}
