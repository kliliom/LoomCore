import Foundation
import LoomCore
import SQLite3
import Testing

@Suite("LoomError Tests")
struct ErrorTests {
  @Test("LoomError from SQLITE_ERROR")
  func testSQLiteError() {
    let error = LoomError(sqlite: SQLITE_ERROR, message: "Test error")

    switch error {
    case let .error(message):
      #expect(message == "Test error")
    default:
      Issue.record("Expected .error case")
    }
  }

  @Test("LoomError from SQLITE_BUSY")
  func testSQLiteBusy() {
    let error = LoomError(sqlite: SQLITE_BUSY, message: "Database is busy")

    switch error {
    case let .busy(message):
      #expect(message == "Database is busy")
    default:
      Issue.record("Expected .busy case")
    }
  }

  @Test("LoomError from SQLITE_CONSTRAINT")
  func testSQLiteConstraint() {
    let error = LoomError(sqlite: SQLITE_CONSTRAINT, message: "Constraint violated")

    switch error {
    case let .constraintViolation(message):
      #expect(message == "Constraint violated")
    default:
      Issue.record("Expected .constraintViolation case")
    }
  }

  @Test("LoomError from SQLITE_NOTFOUND")
  func testSQLiteNotFound() {
    let error = LoomError(sqlite: SQLITE_NOTFOUND, message: "Not found")

    switch error {
    case let .notFound(message):
      #expect(message == "Not found")
    default:
      Issue.record("Expected .notFound case")
    }
  }

  @Test("LoomError from SQLITE_READONLY")
  func testSQLiteReadOnly() {
    let error = LoomError(sqlite: SQLITE_READONLY, message: "Read only")

    switch error {
    case let .readOnly(message):
      #expect(message == "Read only")
    default:
      Issue.record("Expected .readOnly case")
    }
  }

  @Test("LoomError from SQLITE_CANTOPEN")
  func testSQLiteCannotOpen() {
    let error = LoomError(sqlite: SQLITE_CANTOPEN, message: "Cannot open")

    switch error {
    case let .cannotOpen(message):
      #expect(message == "Cannot open")
    default:
      Issue.record("Expected .cannotOpen case")
    }
  }

  @Test("LoomError from SQLITE_NOMEM")
  func testSQLiteNoMemory() {
    let error = LoomError(sqlite: SQLITE_NOMEM, message: "Out of memory")

    switch error {
    case let .noMemory(message):
      #expect(message == "Out of memory")
    default:
      Issue.record("Expected .noMemory case")
    }
  }

  @Test("LoomError from SQLITE_MISMATCH")
  func testSQLiteMismatch() {
    let error = LoomError(sqlite: SQLITE_MISMATCH, message: "Type mismatch")

    switch error {
    case let .dataTypeMismatch(message):
      #expect(message == "Type mismatch")
    default:
      Issue.record("Expected .dataTypeMismatch case")
    }
  }

  @Test("LoomError from unknown SQLite code")
  func testUnknownSQLiteCode() {
    let error = LoomError(sqlite: 999, message: "Unknown error")

    switch error {
    case let .otherSQLiteError(code, message):
      #expect(code == 999)
      #expect(message == "Unknown error")
    default:
      Issue.record("Expected .otherSQLiteError case")
    }
  }

  @Test("LoomError notAFileURL")
  func testNotAFileURL() {
    let error = LoomError.notAFileURL

    switch error {
    case .notAFileURL:
      // Success
      break
    default:
      Issue.record("Expected .notAFileURL case")
    }
  }

  @Test("LoomError emptyStatement")
  func testEmptyStatement() {
    let error = LoomError.emptyStatement

    switch error {
    case .emptyStatement:
      // Success
      break
    default:
      Issue.record("Expected .emptyStatement case")
    }
  }

  @Test("LoomError unexpectedNullValue")
  func testUnexpectedNullValue() {
    let error = LoomError.unexpectedNullValue

    switch error {
    case .unexpectedNullValue:
      // Success
      break
    default:
      Issue.record("Expected .unexpectedNullValue case")
    }
  }

  @Test("LoomError typeMappingFailed")
  func testTypeMappingFailed() {
    let error = LoomError.typeMappingFailed(value: "test", type: "Int")

    switch error {
    case let .typeMappingFailed(value, type):
      #expect(value == "test")
      #expect(type == "Int")
    default:
      Issue.record("Expected .typeMappingFailed case")
    }
  }

  @Test("LoomError rowNotFound")
  func testRowNotFound() {
    let error = LoomError.rowNotFound

    switch error {
    case .rowNotFound:
      // Success
      break
    default:
      Issue.record("Expected .rowNotFound case")
    }
  }

  @Test("LoomError unsupportedOperation")
  func testUnsupportedOperation() {
    let error = LoomError.unsupportedOperation

    switch error {
    case .unsupportedOperation:
      // Success
      break
    default:
      Issue.record("Expected .unsupportedOperation case")
    }
  }

  @Test("LoomError equality")
  func testErrorEquality() {
    let error1 = LoomError.notAFileURL
    let error2 = LoomError.notAFileURL

    #expect(error1 == error2)

    let error3 = LoomError.error(message: "test")
    let error4 = LoomError.error(message: "test")

    #expect(error3 == error4)

    let error5 = LoomError.error(message: "test1")
    let error6 = LoomError.error(message: "test2")

    #expect(error5 != error6)
  }

  @Test("LoomError from all major SQLite codes")
  func testAllMajorSQLiteCodes() {
    let codes: [(Int32, String)] = [
      (SQLITE_ERROR, "error"),
      (SQLITE_INTERNAL, "internalError"),
      (SQLITE_PERM, "permissionDenied"),
      (SQLITE_ABORT, "aborted"),
      (SQLITE_BUSY, "busy"),
      (SQLITE_LOCKED, "locked"),
      (SQLITE_NOMEM, "noMemory"),
      (SQLITE_READONLY, "readOnly"),
      (SQLITE_INTERRUPT, "interrupted"),
      (SQLITE_IOERR, "ioError"),
      (SQLITE_CORRUPT, "corrupt"),
      (SQLITE_NOTFOUND, "notFound"),
      (SQLITE_FULL, "full"),
      (SQLITE_CANTOPEN, "cannotOpen"),
      (SQLITE_PROTOCOL, "protocolError"),
      (SQLITE_SCHEMA, "schemaChanged"),
      (SQLITE_TOOBIG, "tooBig"),
      (SQLITE_CONSTRAINT, "constraintViolation"),
      (SQLITE_MISMATCH, "dataTypeMismatch"),
      (SQLITE_MISUSE, "misuse"),
    ]

    for (code, _) in codes {
      let error = LoomError(sqlite: code, message: "test")
      // Just verify no crash when creating these errors
      #expect(error != LoomError.notAFileURL)
    }
  }
}
