import Foundation
import LoomCore

struct TaskStore {
    let db: Database

    @DatabaseActor
    func add(_ task: TaskRow) async throws {
        try await db.transaction { db in
            try await db.exec(
                """
                INSERT INTO tasks (id, category_id, title, completed_at, metadata)
                VALUES (\(task.id), \(task.categoryID), \(task.title), \(task.completedAt), \(task.metadata))
                """
            )
        }
    }
}
