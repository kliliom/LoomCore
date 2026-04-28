import Foundation
import LoomCore

extension Database {
    static func openTaskTracker(at url: URL) async throws -> Database {
        let db = try await Database.open(url: url)

        try db.setJournalMode(.wal)
        try db.setSynchronous(.normal)
        try db.setForeignKeys(true)

        return db
    }
}
