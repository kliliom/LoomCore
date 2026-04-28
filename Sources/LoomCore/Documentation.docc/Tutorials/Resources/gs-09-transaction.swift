import Foundation
import LoomCore

@main
struct Notes {
    static func main() async throws {
        let db = try await Database.openInMemory()
        // ... schema setup elided; assume `notes` and `folders` tables ...

        try db.transaction {
            try db.exec("DELETE FROM notes WHERE id = \(noteID)")
            try db.exec(
                """
                INSERT INTO notes (id, body, folder_id, created_at)
                VALUES (\(noteID), \(body), \(targetFolderID), \(createdAt))
                """
            )
        }
    }
}
