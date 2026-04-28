import Foundation
import LoomCore

struct TaskMetadata: Codable, Bindable, Equatable {
    var dueDate: Date?
    var priority: Int?
    var labels: [String]
}
