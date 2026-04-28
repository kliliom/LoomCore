# Transactions and Services

Atomic operations, lock modes, and lifecycle hooks for cache invalidation.

## Overview

A transaction wraps a block of operations so they either all succeed and commit, or none of them are visible (rollback). LoomCore exposes this with a single method:

```swift
try db.transaction {
  try db.exec("INSERT INTO accounts (id, balance) VALUES (\(fromID), \(fromBalance))")
  try db.exec("INSERT INTO accounts (id, balance) VALUES (\(toID), \(toBalance))")
  try db.exec("UPDATE journal SET state = \("posted") WHERE id = \(journalID)")
}
```

If the block returns normally, the transaction commits. If it throws, the transaction rolls back and the error propagates.

## Lock modes

``TransactionKind`` selects the SQLite locking strategy:

- ``TransactionKind/deferred`` — default; locks are acquired lazily as needed. Best concurrency, but writes can fail with `SQLITE_BUSY` if another connection grabs the write lock first.
- ``TransactionKind/immediate`` — acquires the write lock at `BEGIN`. Use when you know the transaction will write and want to fail fast.
- ``TransactionKind/exclusive`` — acquires an exclusive lock at `BEGIN`. No other connection can read or write. Use sparingly — typically only for migrations.

```swift
try db.transaction(kind: .immediate) {
  // ...
}
```

## Nested transactions are not supported

Calling ``Database/transaction(kind:_:)`` from inside an active transaction logs a warning and **runs the block in the existing transaction** rather than creating a savepoint. If the inner block throws, the outer transaction rolls back — there is no per-block isolation.

If you need per-block isolation, structure your code so transactions are only opened at top-level entry points, not inside helper functions.

## Services — lifecycle hooks

Subclass ``Database/Service`` to react to commit and rollback events. Common uses are cache invalidation, change notifications, and audit logging:

```swift
final class CacheInvalidator: Database.Service {
  let cache = Cache()

  override func transactionDidCommit() {
    cache.invalidateAll()
  }
}

let invalidator = db.getService(CacheInvalidator.self)
```

Services are singletons per `Database` instance and per service type. The first ``Database/getService(_:)`` call constructs the service via the inherited `init(database:)`; subsequent calls return the same instance. Use stored-property defaults (or override `init(database:)` to set them up) for any per-service state.

Services receive callbacks for every transaction opened via ``Database/transaction(kind:_:)`` — implicit per-statement transactions (a bare `exec` outside a `transaction` block) do **not** fire service callbacks.

## What rollback failure means

If `ROLLBACK` itself fails (rare — typically only happens with a corrupt or disconnected database), LoomCore re-throws the original error from the block. The connection remains open; subsequent operations may or may not succeed depending on what state SQLite is in.

## Topics

- ``Database/transaction(kind:_:)``
- ``TransactionKind``
- ``Database/Service``
- ``Database/getService(_:)``
