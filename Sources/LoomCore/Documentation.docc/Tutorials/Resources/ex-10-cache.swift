import Foundation
import LoomCore

@DatabaseActor
final class CategoryCountsCache {
    private var counts: [UUID: Int] = [:]

    func count(for categoryID: UUID, computing: () throws -> Int) rethrows -> Int {
        if let cached = counts[categoryID] {
            return cached
        }
        let value = try computing()
        counts[categoryID] = value
        return value
    }

    func invalidate() {
        counts.removeAll()
    }
}
