import Foundation
import LoomCore
import Testing

@Suite("Bindable Convenience Methods Tests")
@DatabaseActor
struct BindableTests {
  // MARK: - Instance Method Tests (Int32 index)

  @Test("Instance method bind with Int32 index")
  func testInstanceMethodBind() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value TEXT)")

    try db.exec(
      raw: "INSERT INTO test (value) VALUES (?)",
      binder: { stmt in
        let testString = "Hello, World!"
        try testString.bind(to: stmt, at: 1)
      }
    )

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try String.column(of: stmt, at: 0)
    }

    #expect(result.first == "Hello, World!")
  }

  @Test("Instance method mutating column with Int32 index")
  func testInstanceMethodMutatingColumn() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value TEXT)")
    try db.exec("INSERT INTO test (value) VALUES ('Test Value')")

    _ = try db.query("SELECT value FROM test") { stmt, _ in
      var value = ""
      try value.column(of: stmt, at: 0)
      #expect(value == "Test Value")
    }
  }

  @Test("Instance method bind with multiple types")
  func testInstanceMethodBindMultipleTypes() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (str TEXT, num INTEGER, flag BOOLEAN)")

    try db.exec(
      raw: "INSERT INTO test (str, num, flag) VALUES (?, ?, ?)",
      binder: { stmt in
        let str = "test"
        let num = 42
        let flag = true

        try str.bind(to: stmt, at: 1)
        try num.bind(to: stmt, at: 2)
        try flag.bind(to: stmt, at: 3)
      }
    )

    let result = try db.query("SELECT str, num, flag FROM test") { stmt, _ in
      let s = try String.column(of: stmt, at: 0)
      let n = try Int.column(of: stmt, at: 1)
      let f = try Bool.column(of: stmt, at: 2)
      return (s, n, f)
    }

    #expect(result.first?.0 == "test")
    #expect(result.first?.1 == 42)
    #expect(result.first?.2 == true)
  }

  // MARK: - Static Method Tests with Managed Index

  @Test("Static method bind with managed index")
  func testStaticMethodBindManagedIndex() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (a INTEGER, b INTEGER, c INTEGER)")

    try db.exec(
      raw: "INSERT INTO test (a, b, c) VALUES (?, ?, ?)",
      binder: { stmt, index in
        try Int.bind(to: stmt, value: 1, at: &index)
        try Int.bind(to: stmt, value: 2, at: &index)
        try Int.bind(to: stmt, value: 3, at: &index)
      }
    )

    let result = try db.query("SELECT a, b, c FROM test") { stmt, _ in
      let a = try Int.column(of: stmt, at: 0)
      let b = try Int.column(of: stmt, at: 1)
      let c = try Int.column(of: stmt, at: 2)
      return (a, b, c)
    }

    #expect(result.first?.0 == 1)
    #expect(result.first?.1 == 2)
    #expect(result.first?.2 == 3)
  }

  @Test("Static method column with managed index")
  func testStaticMethodColumnManagedIndex() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (a TEXT, b INTEGER, c DOUBLE)")
    try db.exec("INSERT INTO test (a, b, c) VALUES ('test', 42, 3.14)")

    let result = try db.query(
      raw: "SELECT a, b, c FROM test",
      stepper: { stmt, index, _ in
        let a = try String.column(of: stmt, at: &index)
        let b = try Int.column(of: stmt, at: &index)
        let c = try Double.column(of: stmt, at: &index)
        return (a, b, c)
      }
    )

    #expect(result.first?.0 == "test")
    #expect(result.first?.1 == 42)
    #expect(result.first?.2 == 3.14)
  }

  @Test("Managed index increments correctly for static methods")
  func testManagedIndexIncrement() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (a INTEGER, b INTEGER, c INTEGER)")

    let bindIndex = ManagedIndex()
    #expect(bindIndex.value == 0)

    try db.exec(
      raw: "INSERT INTO test (a, b, c) VALUES (?, ?, ?)",
      binder: { stmt, index in
        #expect(index.value == 0)
        try Int.bind(to: stmt, value: 10, at: &index)
        #expect(index.value == 1)
        try Int.bind(to: stmt, value: 20, at: &index)
        #expect(index.value == 2)
        try Int.bind(to: stmt, value: 30, at: &index)
        #expect(index.value == 3)
      }
    )

    _ = try db.query(
      raw: "SELECT a, b, c FROM test",
      stepper: { stmt, index, _ in
        #expect(index.value == 0)
        let a = try Int.column(of: stmt, at: &index)
        #expect(index.value == 1)
        let b = try Int.column(of: stmt, at: &index)
        #expect(index.value == 2)
        let c = try Int.column(of: stmt, at: &index)
        #expect(index.value == 3)

        #expect(a == 10)
        #expect(b == 20)
        #expect(c == 30)
      }
    )
  }

  // MARK: - Instance Method Tests with Managed Index

  @Test("Instance method bind with managed index")
  func testInstanceMethodBindManagedIndex() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (a TEXT, b INTEGER, c BOOLEAN)")

    try db.exec(
      raw: "INSERT INTO test (a, b, c) VALUES (?, ?, ?)",
      binder: { stmt, index in
        let str = "hello"
        let num = 100
        let flag = false

        try str.bind(to: stmt, at: &index)
        try num.bind(to: stmt, at: &index)
        try flag.bind(to: stmt, at: &index)
      }
    )

    let result = try db.query("SELECT a, b, c FROM test") { stmt, _ in
      let a = try String.column(of: stmt, at: 0)
      let b = try Int.column(of: stmt, at: 1)
      let c = try Bool.column(of: stmt, at: 2)
      return (a, b, c)
    }

    #expect(result.first?.0 == "hello")
    #expect(result.first?.1 == 100)
    #expect(result.first?.2 == false)
  }

  @Test("Instance method mutating column with managed index")
  func testInstanceMethodMutatingColumnManagedIndex() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (a TEXT, b INTEGER, c DOUBLE)")
    try db.exec("INSERT INTO test (a, b, c) VALUES ('alpha', 999, 2.71)")

    _ = try db.query(
      raw: "SELECT a, b, c FROM test",
      stepper: { stmt, index, _ in
        var str = ""
        var num = 0
        var dbl = 0.0

        try str.column(of: stmt, at: &index)
        try num.column(of: stmt, at: &index)
        try dbl.column(of: stmt, at: &index)

        #expect(str == "alpha")
        #expect(num == 999)
        #expect(dbl == 2.71)
      }
    )
  }

  @Test("Instance method managed index auto-increment")
  func testInstanceMethodManagedIndexAutoIncrement() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (a INTEGER, b INTEGER, c INTEGER, d INTEGER)")

    try db.exec(
      raw: "INSERT INTO test (a, b, c, d) VALUES (?, ?, ?, ?)",
      binder: { stmt, index in
        let val1 = 5
        let val2 = 10
        let val3 = 15
        let val4 = 20

        #expect(index.value == 0)
        try val1.bind(to: stmt, at: &index)
        #expect(index.value == 1)
        try val2.bind(to: stmt, at: &index)
        #expect(index.value == 2)
        try val3.bind(to: stmt, at: &index)
        #expect(index.value == 3)
        try val4.bind(to: stmt, at: &index)
        #expect(index.value == 4)
      }
    )

    let result = try db.query("SELECT a, b, c, d FROM test") { stmt, _ in
      (
        try Int.column(of: stmt, at: 0),
        try Int.column(of: stmt, at: 1),
        try Int.column(of: stmt, at: 2),
        try Int.column(of: stmt, at: 3)
      )
    }

    #expect(result.first?.0 == 5)
    #expect(result.first?.1 == 10)
    #expect(result.first?.2 == 15)
    #expect(result.first?.3 == 20)
  }

  // MARK: - Managed Binder Tests

  @Test("Managed binder property creates correct closure")
  func testManagedBinderProperty() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (value INTEGER)")

    let testValue = 42
    let binder = testValue.managedBinder

    try db.exec(
      raw: "INSERT INTO test (value) VALUES (?)",
      binder: { stmt, index in
        try binder(stmt, &index)
      }
    )

    let result = try db.query("SELECT value FROM test") { stmt, _ in
      try Int.column(of: stmt, at: 0)
    }

    #expect(result.first == 42)
  }

  @Test("Managed binder with multiple values")
  func testManagedBinderMultipleValues() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (a TEXT, b INTEGER, c DOUBLE)")

    let str = "test"
    let num = 123
    let dbl = 45.67

    let strBinder = str.managedBinder
    let numBinder = num.managedBinder
    let dblBinder = dbl.managedBinder

    try db.exec(
      raw: "INSERT INTO test (a, b, c) VALUES (?, ?, ?)",
      binder: { stmt, index in
        try strBinder(stmt, &index)
        try numBinder(stmt, &index)
        try dblBinder(stmt, &index)
      }
    )

    let result = try db.query("SELECT a, b, c FROM test") { stmt, _ in
      (
        try String.column(of: stmt, at: 0),
        try Int.column(of: stmt, at: 1),
        try Double.column(of: stmt, at: 2)
      )
    }

    #expect(result.first?.0 == "test")
    #expect(result.first?.1 == 123)
    #expect(result.first?.2 == 45.67)
  }

  // MARK: - Mixed Usage Tests

  @Test("Mix of static and instance methods")
  func testMixedStaticAndInstanceMethods() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (a INTEGER, b TEXT)")

    try db.exec(
      raw: "INSERT INTO test (a, b) VALUES (?, ?)",
      binder: { stmt in
        try Int.bind(to: stmt, value: 100, at: 1)  // Static method
        let str = "mixed"
        try str.bind(to: stmt, at: 2)  // Instance method
      }
    )

    let result = try db.query("SELECT a, b FROM test") { stmt, _ in
      var num = 0
      try num.column(of: stmt, at: 0)  // Instance mutating method
      let str = try String.column(of: stmt, at: 1)  // Static method
      return (num, str)
    }

    #expect(result.first?.0 == 100)
    #expect(result.first?.1 == "mixed")
  }

  @Test("Convenience methods with optional values")
  func testConvenienceMethodsWithOptionals() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (a TEXT, b INTEGER)")

    try db.exec(
      raw: "INSERT INTO test (a, b) VALUES (?, ?)",
      binder: { stmt, index in
        let optStr: String? = "optional"
        let optNum: Int? = nil

        try optStr.bind(to: stmt, at: &index)
        try optNum.bind(to: stmt, at: &index)
      }
    )

    let result = try db.query(
      raw: "SELECT a, b FROM test",
      stepper: { stmt, index, _ in
        var str: String? = nil
        var num: Int? = nil

        try str.column(of: stmt, at: &index)
        try num.column(of: stmt, at: &index)

        return (str, num)
      }
    )

    #expect(result.first?.0 == "optional")
    #expect(result.first?.1 == nil)
  }

  @Test("Convenience methods with complex types")
  func testConvenienceMethodsWithComplexTypes() async throws {
    let db = try Database.openInMemory()

    try db.exec("CREATE TABLE test (uuid BLOB, data BLOB, date DOUBLE)")

    let uuid = UUID()
    let data = Data([0x01, 0x02, 0x03])
    let date = Date(timeIntervalSince1970: 1234567890.0)

    try db.exec(
      raw: "INSERT INTO test (uuid, data, date) VALUES (?, ?, ?)",
      binder: { stmt, index in
        try uuid.bind(to: stmt, at: &index)
        try data.bind(to: stmt, at: &index)
        try date.bind(to: stmt, at: &index)
      }
    )

    let result = try db.query(
      raw: "SELECT uuid, data, date FROM test",
      stepper: { stmt, index, _ in
        var u = UUID()
        var d = Data()
        var dt = Date.distantPast

        try u.column(of: stmt, at: &index)
        try d.column(of: stmt, at: &index)
        try dt.column(of: stmt, at: &index)

        return (u, d, dt)
      }
    )

    #expect(result.first?.0 == uuid)
    #expect(result.first?.1 == data)
    #expect(result.first?.2 == date)
  }
}
