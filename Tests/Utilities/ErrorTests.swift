import Foundation
import LoomCore
import SQLite3
import Testing

@Suite("LoomError Tests")
struct ErrorTests {
  // MARK: - SQLite errors

  @Test("LoomError.sqlite stores the correct code and message")
  func sqliteError() {
    let error = LoomError.sqlite(SQLITE_BUSY, message: "Database is busy")

    #expect(error.sqlite == .busy)
    #expect(error.message == "Database is busy")
  }

  @Test("LoomError.sqlite with unknown code preserves raw value")
  func sqliteUnknownCode() {
    let error = LoomError.sqlite(999, message: "Unknown")

    #expect(error.sqlite == SQLiteResultCode(rawValue: 999))
    #expect(error.message == "Unknown")
  }

  @Test("sqlite accessor returns nil for non-SQLite errors")
  func sqliteAccessorReturnsNilForCoreError() {
    let error = LoomError.core(.databaseClosed, message: "closed")

    #expect(error.sqlite == nil)
  }

  // MARK: - Core errors

  @Test("LoomError.core stores the correct code and message")
  func coreError() {
    let error = LoomError.core(.nullValue, message: "Column x is null")

    #expect(error.core == .nullValue)
    #expect(error.message == "Column x is null")
  }

  @Test("core accessor returns nil for non-core errors")
  func coreAccessorReturnsNilForSQLiteError() {
    let error = LoomError.sqlite(SQLITE_ERROR, message: "err")

    #expect(error.core == nil)
  }

  // MARK: - SQLiteResultCode

  @Test("SQLiteResultCode debugDescription for known codes")
  func resultCodeDebugDescription() {
    #expect(SQLiteResultCode.ok.debugDescription == "SQLITE_OK")
    #expect(SQLiteResultCode.error.debugDescription == "SQLITE_ERROR")
    #expect(SQLiteResultCode.busy.debugDescription == "SQLITE_BUSY")
    #expect(SQLiteResultCode.constraint.debugDescription == "SQLITE_CONSTRAINT")
  }

  @Test("SQLiteResultCode debugDescription for unknown code")
  func resultCodeDebugDescriptionUnknown() {
    let code = SQLiteResultCode(rawValue: 999)
    #expect(code.debugDescription == "SQLITE_RESULT_CODE(999)")
  }

  @Test(
    "SQLiteResultCode maps all primary result codes",
    arguments: [
      (SQLiteResultCode.abort, SQLITE_ABORT),
      (.auth, SQLITE_AUTH),
      (.busy, SQLITE_BUSY),
      (.cantOpen, SQLITE_CANTOPEN),
      (.constraint, SQLITE_CONSTRAINT),
      (.corrupt, SQLITE_CORRUPT),
      (.done, SQLITE_DONE),
      (.empty, SQLITE_EMPTY),
      (.error, SQLITE_ERROR),
      (.format, SQLITE_FORMAT),
      (.full, SQLITE_FULL),
      (.internal, SQLITE_INTERNAL),
      (.interrupt, SQLITE_INTERRUPT),
      (.ioError, SQLITE_IOERR),
      (.locked, SQLITE_LOCKED),
      (.mismatch, SQLITE_MISMATCH),
      (.misuse, SQLITE_MISUSE),
      (.noLFS, SQLITE_NOLFS),
      (.noMemory, SQLITE_NOMEM),
      (.notADatabase, SQLITE_NOTADB),
      (.notFound, SQLITE_NOTFOUND),
      (.notice, SQLITE_NOTICE),
      (.ok, SQLITE_OK),
      (.permission, SQLITE_PERM),
      (.protocol, SQLITE_PROTOCOL),
      (.range, SQLITE_RANGE),
      (.readOnly, SQLITE_READONLY),
      (.row, SQLITE_ROW),
      (.schema, SQLITE_SCHEMA),
      (.tooBig, SQLITE_TOOBIG),
      (.warning, SQLITE_WARNING),
    ] as [(SQLiteResultCode, Int32)]
  )
  func resultCodeRawValues(code: SQLiteResultCode, expected: Int32) {
    #expect(code.rawValue == expected)
  }
}
