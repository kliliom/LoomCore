import Foundation
import LoomCore

@main
struct Notes {
    static func main() async throws {
        let db = try await Database.openInMemory()
        // ... schema setup elided; assume `notes` and `folders` tables ...

        let noteID = 1
        let body = "Pick up the dry cleaning"
        let targetFolderID = 2
        let createdAt = Date()

        try await db.transaction { db in
            try await db.exec("DELETE FROM notes WHERE id = \(noteID)")
            try await db.exec(
                """
                INSERT INTO notes (id, body, folder_id, created_at)
                VALUES (\(noteID), \(body), \(targetFolderID), \(createdAt))
                """
            )
        }
    }
}
