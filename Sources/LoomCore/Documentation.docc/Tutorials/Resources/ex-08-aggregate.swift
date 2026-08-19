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

extension TaskStore {
    @DatabaseActor
    func openTasks(in categoryID: UUID) async throws -> [TaskRow] {
        let predicate =
            TaskColumns.categoryID == categoryID
            && TaskColumns.completedAt.isNull()

        return try await db.query(
            """
            SELECT id, category_id, title, completed_at, metadata
            FROM tasks
            WHERE \(predicate)
            ORDER BY id
            """,
            stepper: { stmt, index, _ in
                TaskRow(
                    id: try Int.column(of: stmt, at: &index),
                    categoryID: try UUID.column(of: stmt, at: &index),
                    title: try String.column(of: stmt, at: &index),
                    completedAt: try Date?.column(of: stmt, at: &index),
                    metadata: try TaskMetadata?.column(of: stmt, at: &index)
                )
            }
        )
    }
}

extension TaskStore {
    @DatabaseActor
    func openTitles(for categoryID: UUID) async throws -> [String] {
        // GROUP_CONCAT returns a single comma-separated row, or NULL for an empty group.
        let titles = TaskColumns.title.groupConcat(separator: ", ")
        let predicate =
            TaskColumns.categoryID == categoryID
            && TaskColumns.completedAt.isNull()

        let row = try await db.query(
            "SELECT \(titles) FROM tasks WHERE \(predicate)",
            stepper: { stmt, _ in try String?.column(of: stmt, at: 0) }
        ).first

        return (row ?? nil)?.components(separatedBy: ", ") ?? []
    }
}
