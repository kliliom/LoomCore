import Foundation
import SQLite3

extension Database {
  /// Captures the ROWID of the last row inserted by the given block.
  ///
  /// This method executes a block of code and returns the ROWID of the last row inserted
  /// during that block's execution. It's particularly useful for retrieving auto-generated
  /// primary keys after INSERT operations.
  ///
  /// SQLite automatically assigns a unique ROWID to each row in tables without an
  /// `INTEGER PRIMARY KEY` column, or uses the `INTEGER PRIMARY KEY` value if present.
  /// This method captures that value immediately after the insert.
  ///
  /// The following example demonstrates capturing the last inserted row ID:
  ///
  ///     let rowID = try await db.lastInsertedRowID {
  ///       try db.exec("INSERT INTO users (name, age) VALUES ('Foo', 42)")
  ///     }
  ///     if let rowID {
  ///       print("Inserted row with ROWID: \(rowID)")
  ///     }
  ///
  /// - Important: This method resets the last insert ROWID to 0 before executing the block
  ///              to ensure you only capture ROWIDs from operations within the block, not
  ///              from previous unrelated inserts.
  ///
  /// - Note: If multiple rows are inserted within the block, only the ROWID of the very
  ///         last insert is returned. If you need to track multiple inserts, call this
  ///         method separately for each INSERT statement.
  ///
  /// - Parameter block: A closure containing INSERT operations. Must be isolated to ``DatabaseActor``.
  /// - Returns: The ROWID of the last inserted row, or `nil` if no row was inserted or
  ///            the insert doesn't generate a ROWID (e.g., `WITHOUT ROWID` tables).
  /// - Throws: ``LoomError`` if the block's database operations fail (e.g., constraint
  ///           violations, SQL syntax errors, I/O errors).
  public func lastInsertedRowID(_ block: @DatabaseActor () throws -> Void) throws -> Int64? {
    sqlite3_set_last_insert_rowid(db.ptr, 0)
    try block()
    let id = sqlite3_last_insert_rowid(db.ptr)
    guard id != 0 else { return nil }
    return id
  }
}
