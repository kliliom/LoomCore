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

        for column in try await db.tableInfo("notes") {
            print("\(column.name): \(column.type)\(column.notNull ? " NOT NULL" : "")")
        }
        // id: INTEGER
        // body: TEXT NOT NULL
        // created_at: REAL NOT NULL
    }
}
