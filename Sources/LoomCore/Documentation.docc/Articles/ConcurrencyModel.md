# Concurrency and Actor Isolation

How LoomCore makes SQLite race-free without explicit locking.

## Overview

SQLite is thread-safe in the sense that the C library can be configured to serialize access internally, but using it correctly from Swift still requires discipline — prepared statements, transactions, and the connection state are all stateful and must not be touched from multiple threads concurrently.

LoomCore uses a **single global actor** to serialize every `sqlite3_*` call:

```swift
@globalActor
public actor DatabaseActor {
  public static let shared = DatabaseActor()
}
```

Every public method on ``Database``, every static method on ``Bindable``, and every closure passed in (`Binder`, `Stepper`, `transaction`'s body) is `@DatabaseActor`-isolated. Swift's compiler enforces this at the call site — you cannot call into LoomCore from arbitrary async code without first hopping to the actor.

## What this guarantees

- No two SQLite calls run at the same time, ever, in your process.
- No accidental shared mutable state between callers — the actor is the single point of synchronization.
- `Sendable` values you pass into binders and steppers are safe to capture; mutable references are flagged at compile time.
- Once an operation starts executing, it runs to completion synchronously on the actor. Interleaving between tasks happens only at suspension points — never in the middle of a statement.

## The transaction gate

Actor isolation alone is not enough for transactions: ``DatabaseActor`` releases its executor at every `await`, so a transaction body that suspends would otherwise let another task's statements run inside the open transaction. LoomCore closes that hole with a **gate**.

While a transaction is in flight — including while its body is suspended — database operations from tasks outside the transaction suspend at the gate and resume once the transaction commits or rolls back. Membership is a task-local token bound around the transaction block: structured children (`async let`, task groups) and unstructured `Task {}` inherit it and run inside the transaction — an unstructured task must complete before the body returns, or it races the commit; `Task.detached` does not inherit it and waits like any outside caller. An operation waiting at the gate throws `CancellationError` if its task is cancelled.

The gate is what makes `await` inside a transaction body safe. When no transaction is active it costs a single nil check. See <doc:TransactionsAndServices> for the full semantics, including savepoint nesting.

## Cancellation

Cancellation is ambient — no opt-in, no API knob:

- **Waiting at the gate** — a cancelled waiter resumes throwing `CancellationError`, leaving the in-flight transaction undisturbed.
- **Mid-statement** — cancelling a task whose `exec`, `query`, or `execScript` is stepping aborts the statement via `sqlite3_interrupt` (the one SQLite call that is safe cross-thread on a live connection) and throws `CancellationError`. This works even inside a single long-running step, and a per-operation ticket guarantees a late-firing cancellation can never abort a different task's statement.

An interrupted **write** inside an explicit transaction makes SQLite roll the whole transaction back; ``Database/transaction(kind:_:)`` recognizes that, reports a rollback to services, and leaves the connection open.

``Database/interrupt()`` exposes the same abort switch directly — it is `nonisolated`, so any thread can stop a long query on a busy connection without cancelling the task running it. The interrupted operation throws ``LoomError`` with ``SQLiteResultCode/interrupt``.

``Database/directAccess(_:)`` is the exception: it runs no LoomCore statements, so nothing is armed — code inside it manages its own cancellation.

## What this rules out

- **Concurrent reads against the same `Database`.** Even if SQLite would allow it (e.g. in WAL mode), LoomCore serializes everything through the actor. If you want true read parallelism, open multiple ``Database`` instances against the same file — each has its own connection and runs on its own actor turn.
- **Cross-actor `StatementHandle` use.** ``StatementHandle`` and ``DatabaseHandle`` are `~Copyable` and isolated to ``DatabaseActor``. They cannot escape into other contexts.

## Resource cleanup

``DatabaseHandle`` owns the `sqlite3*` pointer plus the prepared-statement cache. It is `~Copyable` to enforce single ownership. Cleanup happens in two ways:

1. **Explicit close** — `db.close()` finalizes cached statements and closes the connection eagerly.
2. **`deinit`** — the handle dispatches a `Task { @DatabaseActor … }` that runs the same cleanup. Because deinit can run on any thread, the cleanup work is moved into a `Task` whose body is on ``DatabaseActor``.

The cache is captured via a small reference-counted `ResourceStore` so it survives the move into the cleanup task. You should not normally see this internal structure — it just means resources are released safely without you having to think about it.

## Working with SwiftUI and structured concurrency

`Database` is `Sendable`, so it can be passed across actor boundaries. The methods that mutate it are isolated to ``DatabaseActor``:

```swift
struct User: Sendable {
  let id: Int
  let name: String
}

@MainActor
final class UserStore {
  let db: Database

  init(db: Database) {
    self.db = db
  }

  func loadUsers() async throws -> [User] {
    try await db.query("SELECT id, name FROM users") { stmt, _ in
      User(
        id: try Int.column(of: stmt, at: 0),
        name: try String.column(of: stmt, at: 1)
      )
    }
  }
}
```

The `await` is the actor hop from `@MainActor` to ``DatabaseActor``. Results returned to the main actor must be `Sendable`.

## Topics

- ``Database``
- ``DatabaseActor``
- ``DatabaseHandle``
- ``StatementHandle``
