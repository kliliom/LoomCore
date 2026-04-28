import Foundation
import LoomCore

struct MoveCancelled: Error {}

@main
struct Notes {
    static func main() async throws {
        let db = try await Database.openInMemory()
        // ... schema setup elided ...

        do {
            try db.transaction {
                try db.exec("DELETE FROM notes WHERE id = \(noteID)")
                // Simulate a validation failure mid-transaction.
                throw MoveCancelled()
            }
        } catch is MoveCancelled {
            // The DELETE was rolled back; the row is still there.
            let count = try db.query("SELECT COUNT(*) FROM notes WHERE id = \(noteID)") { stmt, _ in
                try Int.column(of: stmt, at: 0)
            }
            assert(count.first == 1)
        }
    }
}
