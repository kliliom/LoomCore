/// Invariants every user statement is held to, so that user SQL cannot change transaction
/// state behind the transaction machinery's back or silently run with missing parameters.

import SQLite3

extension Database {
  /// Throws when SQLite already rolled back the enclosing ``transaction(kind:_:)``.
  ///
  /// An interrupted or conflict-resolved write (`sqlite3_interrupt`, `ON CONFLICT ROLLBACK`)
  /// rolls the physical transaction back underneath the body. A body that catches that error
  /// and carries on would otherwise run every later statement in autocommit mode — each one
  /// durable on its own — while the scope still reports a rollback.
  func ensureTransactionIntact() throws {
    guard activeTransactionToken != nil, try sqlite3_get_autocommit(handle.ptr) != 0 else { return }
    throw LoomError.core(
      .transactionScopeLost,
      message: "The enclosing transaction was already rolled back by SQLite after an interrupted or "
        + "conflict-resolved write; refusing to run further statements outside it."
    )
  }
}

extension StatementHandle {
  /// Throws unless exactly `bound` values cover every parameter the prepared statement declares.
  ///
  /// An uncovered placeholder — a literal `?` left in interpolated SQL, or too few values — would
  /// otherwise evaluate as `NULL` without any error.
  func requireParameterCount(_ bound: Int32) throws {
    let expected = sqlite3_bind_parameter_count(stmtPtr)
    guard bound != expected else { return }
    throw LoomError.core(
      .parameterCountMismatch,
      message: "Statement declares \(expected) parameter(s) but \(bound) value(s) were bound."
    )
  }
}
