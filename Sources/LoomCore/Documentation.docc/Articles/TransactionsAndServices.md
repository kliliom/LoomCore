# Transactions and Services

Atomic operations, savepoint nesting, transaction gating, and lifecycle hooks for cache invalidation.

## Overview

A transaction wraps a block of operations so they either all succeed and commit, or none of them are visible (rollback). LoomCore exposes this with a single method — the block is async, receives the database it runs on, and may suspend freely:

```swift
let fromID = 1
let toID = 2
let fromBalance = 90.0
let toBalance = 210.0
let journalID = 7

try await db.transaction { db in
  try await db.exec("INSERT INTO accounts (id, balance) VALUES (\(fromID), \(fromBalance))")
  try await db.exec("INSERT INTO accounts (id, balance) VALUES (\(toID), \(toBalance))")
  try await db.exec("UPDATE journal SET state = \("posted") WHERE id = \(journalID)")
}
```

If the block returns normally, the transaction commits. If it throws, the transaction rolls back and the error propagates. Atomicity is preserved across `await`s inside the block — see the gating section below for how.

### Lock modes

``TransactionKind`` selects the SQLite locking strategy:

- ``TransactionKind/deferred`` — default; locks are acquired lazily as needed. Best concurrency, but writes can fail with `SQLITE_BUSY` if another connection grabs the write lock first.
- ``TransactionKind/immediate`` — acquires the write lock at `BEGIN`. Use when you know the transaction will write and want to fail fast.
- ``TransactionKind/exclusive`` — acquires an exclusive lock at `BEGIN`. No other connection can read or write. Use sparingly — typically only for migrations.

```swift
try await db.transaction(kind: .immediate) { db in
  // ...
}
```

`kind` applies to the outermost transaction only — nested calls open savepoints, which have no locking mode, so the parameter is ignored for them.

### Nested transactions — savepoints

Calling ``Database/transaction(kind:_:)`` from inside an active transaction opens a `SAVEPOINT` scope. If the nested block returns normally, the savepoint is released and its work joins the enclosing transaction. If it throws, LoomCore rolls back to the savepoint — undoing only the nested block's work, leaving the enclosing transaction intact — and rethrows the error:

```swift
struct NoteRejected: Error {}

let orderID = 1
let note = "gift wrap, please"

try await db.transaction { db in
  try await db.exec("INSERT INTO orders (id) VALUES (\(orderID))")

  do {
    try await db.transaction { db in
      try await db.exec("INSERT INTO order_notes (order_id, note) VALUES (\(orderID), \(note))")
      throw NoteRejected()
    }
  } catch is NoteRejected {
    // The note insert was rolled back; the order insert is still pending.
  }

  // Commits the order (without the note).
}
```

Nothing inside a savepoint scope — released or not — becomes durable until the outermost transaction commits. Sibling child tasks that each open a nested transaction are serialized automatically by the gate, so their savepoint scopes never interleave (SQLite savepoints are a stack).

### Transaction gating

`DatabaseActor` releases its executor at every suspension point, so an `await` inside a transaction body would — without further machinery — let another task's statements run inside the open transaction. LoomCore prevents this with a gate: while a transaction is in flight, even while its body is suspended, database operations from tasks *outside* the transaction suspend and resume once the transaction commits or rolls back.

Membership is tracked by a task-local token bound around the block:

- **Structured children** (`async let`, task groups) and **unstructured `Task {}`** inherit the token and operate inside the transaction. An unstructured task must complete before the body returns (await its value); a task that outlives the body races the commit and may run outside the transaction.
- **`Task.detached`** does not inherit it — a detached task waits at the gate like any outside caller. Awaiting a detached task's database work from inside the transaction body therefore deadlocks.
- An operation waiting at the gate throws `CancellationError` if its task is cancelled.

Once past the gate, an operation runs to completion synchronously on `DatabaseActor` — interleaving between tasks happens only at gates and suspension points, never mid-statement. When no transaction is active the gate is a single nil check, so ungated workloads pay essentially nothing.

### Services — lifecycle hooks

Subclass ``Database/Service`` to react to transaction lifecycle events. Common uses are cache invalidation, change notifications, and audit logging:

```swift
@DatabaseActor
final class Cache {
  private var entries: [String: Int] = [:]

  func invalidateAll() {
    entries.removeAll()
  }
}

final class CacheInvalidator: Database.Service {
  let cache = Cache()

  override func transactionDidCommit() {
    cache.invalidateAll()
  }
}

let invalidator = await db.getService(CacheInvalidator.self)
```

Services are singletons per `Database` instance and per service type. The first ``Database/getService(_:)`` call constructs the service via the inherited `init(database:)`; subsequent calls return the same instance. Use stored-property defaults (or override `init(database:)` to set them up) for any per-service state.

Services receive ``Database/Service/transactionWillBegin()``, ``Database/Service/transactionDidCommit()``, and ``Database/Service/transactionDidRollback()`` **only for the outermost physical transaction**. Nested (savepoint) scopes fire no callbacks — they describe intermediate state that only becomes durable when the outer transaction commits. Implicit per-statement transactions (a bare `exec` outside a `transaction` block) do not fire service callbacks either.

### What rollback failure means

Some failures roll the physical transaction back inside SQLite itself — an interrupted write (``Database/interrupt()`` or task cancellation) and `ON CONFLICT ROLLBACK` constraints both do. LoomCore detects that, skips its own now-pointless `ROLLBACK`, still notifies services via ``Database/Service/transactionDidRollback()``, and rethrows the block's error with the connection intact.

If `ROLLBACK` itself fails on a transaction that is genuinely still open (rare — typically only a corrupt or disconnected database), LoomCore logs a warning, closes the underlying handle, and rethrows the original error from the block. Subsequent operations on the database fail with a closed-database error.

### Handling SQLITE_BUSY

A second connection — another process, or another `Database` on the same file — can hold a lock that makes a statement fail with ``SQLiteResultCode/busy``. Three tools, in the order to reach for them:

- **``Database/setBusyTimeout(milliseconds:)``** — SQLite retries the lock inside `sqlite3_step` for up to the timeout before failing. Keep it modest: the wait sleeps while holding the global ``DatabaseActor``, stalling every `Database` in the process for its duration. ``Database/interrupt()`` (and task cancellation) aborts a busy wait.
- **``TransactionKind/immediate``** — a transaction that will write should fail fast at `BEGIN` rather than mid-transaction after doing work.
- **Retry at the call site** — for contention that outlasts a reasonable timeout:

```swift
func withBusyRetry<T>(_ attempts: Int = 3, _ body: () async throws -> T) async throws -> T {
  for _ in 0..<(attempts - 1) {
    do {
      return try await body()
    } catch let error as LoomError where error.sqlite == .busy {
      try await Task.sleep(for: .milliseconds(50))
    }
  }
  return try await body()
}
```

Enabling WAL mode (``Database/setJournalMode(_:)``) also removes most reader/writer contention between connections to the same file.

## Topics

- ``Database/transaction(kind:_:)``
- ``TransactionKind``
- ``Database/Service``
- ``Database/getService(_:)``
- ``Database/setBusyTimeout(milliseconds:)``
- ``Database/interrupt()``
