import Foundation
import LoomCore

extension Database {
    static func openTaskTracker(at url: URL) async throws -> Database {
        let db = try await Database.open(url: url)

        try await db.setJournalMode(.wal)
        try await db.setSynchronous(.normal)
        try await db.setForeignKeys(true)

        return db
    }
}
