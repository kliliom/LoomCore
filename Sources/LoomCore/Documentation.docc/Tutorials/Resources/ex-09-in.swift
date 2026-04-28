extension TaskStore {
    @DatabaseActor
    func tasks(inAnyOf categoryIDs: [UUID]) throws -> [TaskRow] {
        // An empty array renders as `( category_id IN (NULL) AND 0 )`,
        // which is an always-false predicate — no special-casing needed.
        let predicate = TaskColumns.categoryID.in(array: categoryIDs)

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
