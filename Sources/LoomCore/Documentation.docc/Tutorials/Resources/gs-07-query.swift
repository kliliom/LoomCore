import Foundation
import LoomCore

@main
struct Notes {
    static func main() async throws {
        let db = try await Database.openInMemory()
        // ... schema and inserts elided ...

        let notes = try await db.query("SELECT id, body FROM notes ORDER BY created_at") { stmt, _ in
            let id = try Int.column(of: stmt, at: 0)
            let body = try String.column(of: stmt, at: 1)
            return (id, body)
        }

        for (id, body) in notes {
            print("\(id): \(body)")
        }
    }
}
