import Foundation
import SQLite3

extension Database {
  /// Captures the ROWID of the last row inserted by the given block.
  ///
  /// Resets SQLite's last-insert ROWID to 0 before running `block`, so the returned value
  /// only reflects inserts performed inside the closure. For tables with an
  /// `INTEGER PRIMARY KEY`, the ROWID is that primary key; for other rowid tables, SQLite
  /// assigns one automatically. `WITHOUT ROWID` tables do not generate a ROWID.
  ///
  /// ```swift
  /// let userID = try await db.lastInsertedRowID {
  ///   try db.exec("INSERT INTO users (name, email) VALUES (?, ?)", "Alice", "alice@example.com")
  ///   try db.exec("INSERT INTO audit_log (action, user) VALUES (?, ?)", "create", "Alice")
  /// }
  /// // userID is the ROWID of the audit_log insert — the last one in the block.
  /// ```
  ///
  /// When the block performs multiple inserts, only the final insert's ROWID is returned.
  /// Wrap each insert in its own call to track them individually.
  ///
  /// - Returns: ROWID of the last insert, or `nil` if none occurred or the target table
  ///            does not generate ROWIDs.
  public func lastInsertedRowID(_ block: @DatabaseActor () throws -> Void) throws -> Int64? {
    let dbPtr = try handle.ptr
    sqlite3_set_last_insert_rowid(dbPtr, 0)
    try block()
    let id = sqlite3_last_insert_rowid(dbPtr)
    guard id != 0 else { return nil }
    return id
  }
}
