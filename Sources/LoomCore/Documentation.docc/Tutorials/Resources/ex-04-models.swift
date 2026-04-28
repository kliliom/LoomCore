import Foundation
import LoomCore

struct TaskMetadata: Codable, Bindable, Equatable {
    var dueDate: Date?
    var priority: Int?
    var labels: [String]
}

struct Category {
    let id: UUID
    let name: String
}

struct TaskRow {
    let id: Int
    let categoryID: UUID
    let title: String
    let completedAt: Date?
    let metadata: TaskMetadata?
}
