import Foundation
import LoomCore

struct Note {
    let id: Int
    let body: String
    let createdAt: Date
}

@main
struct Notes {
    static func main() async throws {
        let db = try await Database.openInMemory()
        // ... schema and inserts elided ...

        let notes: [Note] = try db.query(
            raw: "SELECT id, body, created_at FROM notes ORDER BY created_at",
            stepper: { stmt, index, _ in
                Note(
                    id: try Int.column(of: stmt, at: &index),
                    body: try String.column(of: stmt, at: &index),
                    createdAt: try Date.column(of: stmt, at: &index)
                )
            }
        )

        for note in notes {
            print(note)
        }
    }
}
