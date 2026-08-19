import LoomCore
import Testing

@Suite("ColumnExpression Tests")
struct ColumnExpressionTests {
  @Test("Unqualified column quotes the name")
  func testUnqualifiedColumn() {
    let column = ColumnExpression<Int>("age")
    var builder = SQLBuilder()
    column.append(to: &builder)
    #expect(builder.makeStatement().sql == "\"age\"")
  }

  @Test("Qualified column quotes both names")
  func testQualifiedColumn() {
    let column = ColumnExpression<String>("email", of: "users")
    var builder = SQLBuilder()
    column.append(to: &builder)
    #expect(builder.makeStatement().sql == "\"users\".\"email\"")
  }

  @Test("Stores column and table names verbatim")
  func testStoredNames() {
    let unqualified = ColumnExpression<Int>("age")
    #expect(unqualified.columnName == "age")
    #expect(unqualified.tableName == nil)

    let qualified = ColumnExpression<String>("email", of: "users")
    #expect(qualified.columnName == "email")
    #expect(qualified.tableName == "users")
  }

  @Test("Embedded double quotes are doubled when escaping")
  func testEmbeddedQuoteEscaping() {
    let column = ColumnExpression<Int>("weird\"name")
    var builder = SQLBuilder()
    column.append(to: &builder)
    #expect(builder.makeStatement().sql == "\"weird\"\"name\"")
  }

  @Test("A double quote followed by a combining scalar is still doubled")
  func testCombiningScalarQuoteEscaping() {
    // Grapheme-level search would see `"` + U+0301 as a single character and skip the
    // quote; escaping must operate on Unicode scalars.
    let column = ColumnExpression<Int>("weird\"\u{301}name")
    var builder = SQLBuilder()
    column.append(to: &builder)

    #expect(builder.makeStatement().sql == "\"weird\"\"\u{301}name\"")
  }

  @Test("Reserved word column name is safely quoted")
  func testReservedWordColumn() {
    let column = ColumnExpression<Int>("order")
    var builder = SQLBuilder()
    column.append(to: &builder)
    #expect(builder.makeStatement().sql == "\"order\"")
  }

  @Test("Column name with spaces is quoted as a single identifier")
  func testNameWithSpaces() {
    let column = ColumnExpression<Int>("user id")
    var builder = SQLBuilder()
    column.append(to: &builder)
    #expect(builder.makeStatement().sql == "\"user id\"")
  }

  @Test("Qualified column with embedded quotes in both names")
  func testQualifiedColumnWithEmbeddedQuotes() {
    let column = ColumnExpression<Int>("a\"b", of: "c\"d")
    var builder = SQLBuilder()
    column.append(to: &builder)
    #expect(builder.makeStatement().sql == "\"c\"\"d\".\"a\"\"b\"")
  }
}
