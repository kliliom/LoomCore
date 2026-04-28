import Foundation
import LoomCore

@main
struct Notes {
    static func main() async throws {
        let db = try await Database.openInMemory()

        try db.exec(
            """
            CREATE TABLE notes (
              id INTEGER PRIMARY KEY,
              body TEXT NOT NULL,
              created_at REAL NOT NULL
            )
            """
        )
    }
}
