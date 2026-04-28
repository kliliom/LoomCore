extension TaskStore {
    @DatabaseActor
    func openCount(for categoryID: UUID) throws -> Int {
        let service = db.getService(CategoryCountsService.self)

        return try service.cache.count(for: categoryID) {
            let predicate =
                TaskColumns.categoryID == categoryID
                && TaskColumns.completedAt.isNull()

            let rows = try db.query("SELECT COUNT(*) FROM tasks WHERE \(predicate)") { stmt, _ in
                try Int.column(of: stmt, at: 0)
            }
            return rows.first ?? 0
        }
    }
}
