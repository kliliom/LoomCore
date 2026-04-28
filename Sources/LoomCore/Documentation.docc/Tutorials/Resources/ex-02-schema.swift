import Foundation
import LoomCore

extension Database {
    static func openTaskTracker(at url: URL) async throws -> Database {
        let db = try await Database.open(url: url)

        try db.setJournalMode(.wal)
        try db.setSynchronous(.normal)
        try db.setForeignKeys(true)

        try db.exec(
            """
            CREATE TABLE IF NOT EXISTS categories (
              id BLOB PRIMARY KEY,
              name TEXT NOT NULL UNIQUE
            )
            """
        )
        try db.exec(
            """
            CREATE TABLE IF NOT EXISTS tasks (
              id INTEGER PRIMARY KEY,
              category_id BLOB NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
              title TEXT NOT NULL,
              completed_at REAL,
              metadata BLOB
            )
            """
        )

        return db
    }
}
