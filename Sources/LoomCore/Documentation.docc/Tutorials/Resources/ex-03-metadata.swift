import Foundation
import LoomCore

struct TaskMetadata: Codable, JSONBindable, Equatable {
    var dueDate: Date?
    var priority: Int?
    var labels: [String]
}
