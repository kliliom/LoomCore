extension TaskStore {
    @DatabaseActor
    func openTitles(for categoryID: UUID) throws -> [String] {
        // GROUP_CONCAT returns a single comma-separated row, or NULL for an empty group.
        let titles = TaskColumns.title.groupConcat(separator: ", ")
        let predicate =
            TaskColumns.categoryID == categoryID
            && TaskColumns.completedAt.isNull()

        let row = try db.query(
            "SELECT \(titles) FROM tasks WHERE \(predicate)",
            stepper: { stmt, _ in try String?.column(of: stmt, at: 0) }
        ).first

        return (row ?? nil)?.components(separatedBy: ", ") ?? []
    }
}
