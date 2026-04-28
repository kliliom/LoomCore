import Foundation
import LoomCore

@DatabaseActor
final class CategoryCountsService: Database.Service {
    let cache = CategoryCountsCache()

    override func transactionDidCommit() {
        cache.invalidate()
    }

    override func transactionDidRollback() {
        // No-op: the cache only mirrors committed state, so a rolled-back
        // transaction did not change anything we could be caching.
    }
}
