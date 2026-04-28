import Foundation
import LoomCore

enum TaskColumns {
    static let id = ColumnExpression<Int>("id", of: "tasks")
    static let categoryID = ColumnExpression<UUID>("category_id", of: "tasks")
    static let title = ColumnExpression<String>("title", of: "tasks")
    static let completedAt = ColumnExpression<Date?>("completed_at", of: "tasks")
    static let metadata = ColumnExpression<TaskMetadata?>("metadata", of: "tasks")
}
