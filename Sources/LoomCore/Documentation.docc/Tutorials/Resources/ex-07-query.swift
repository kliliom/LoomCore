extension TaskStore {
    @DatabaseActor
    func openTasks(in categoryID: UUID) throws -> [TaskRow] {
        let predicate =
            TaskColumns.categoryID == categoryID
            && TaskColumns.completedAt.isNull()

        return try db.query(
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
