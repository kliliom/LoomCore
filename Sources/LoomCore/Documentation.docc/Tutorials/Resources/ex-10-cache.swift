import Foundation
import LoomCore

@DatabaseActor
final class CategoryCountsCache {
    private var counts: [UUID: Int] = [:]

    func count(for categoryID: UUID, computing: () async throws -> Int) async rethrows -> Int {
        if let cached = counts[categoryID] {
            return cached
        }
        let value = try await computing()
        counts[categoryID] = value
        return value
    }

    func invalidate() {
        counts.removeAll()
    }
}
