import Foundation
import LoomCore

@main
struct Notes {
    static func main() async throws {
        let db = try await Database.openInMemory()

        try await db.exec(
            """
            CREATE TABLE notes (
              id INTEGER PRIMARY KEY,
              body TEXT NOT NULL,
              created_at REAL NOT NULL
            )
            """
        )

        let body = "Pick up groceries"
        let createdAt = Date()
        try await db.exec(
            "INSERT INTO notes (body, created_at) VALUES (\(body), \(createdAt))"
        )
    }
}
