# Index Conventions

How LoomCore handles SQLite's asymmetric 1-based parameter / 0-based column indexing.

## Overview

SQLite uses two different indexing conventions, and getting them wrong is a common source of subtle bugs:

- **Parameter binding is 1-based.** The leftmost `?` in a prepared statement is index `1`.
- **Column extraction is 0-based.** The leftmost column in a result row is index `0`.

LoomCore preserves these conventions exactly rather than normalizing them, because flattening would hide which side of the API you are on and make off-by-one errors easier — not harder.

```swift
// Parameter indices are 1-based:
try await db.exec(
  raw: "INSERT INTO users (name, age) VALUES (?, ?)",
  binder: { stmt in
    try "Alice".bind(to: stmt, at: 1)  // leftmost ?
    try 30.bind(to: stmt, at: 2)       // second ?
  }
)

// Column indices are 0-based:
let rows = try await db.query(raw: "SELECT name, age FROM users") { stmt, _ in
  let name = try String.column(of: stmt, at: 0)  // leftmost column
  let age  = try Int.column(of: stmt, at: 1)     // second column
  return (name, age)
}
```

## Avoiding off-by-one errors

For multi-column statements, the safest pattern is ``ManagedIndex``. It auto-increments around binds and column reads — for parameters it increments *before* binding, so the first bind hits index 1; for columns it increments *after* reading, so the first read hits index 0.

```swift
struct User {
  let id: Int
  let name: String
  let email: String
  let age: Int
}

let users = try await db.query(
  raw: "SELECT id, name, email, age FROM users WHERE status = ?",
  binder: { stmt, index in
    try "active".bind(to: stmt, at: &index)        // → param 1
  },
  stepper: { stmt, index, stop in
    let id    = try Int.column(of: stmt, at: &index)     // → column 0
    let name  = try String.column(of: stmt, at: &index)  // → column 1
    let email = try String.column(of: stmt, at: &index)  // → column 2
    let age   = try Int.column(of: stmt, at: &index)     // → column 3
    return User(id: id, name: name, email: email, age: age)
  }
)
```

When you add or remove a column, the indices shift automatically. There are no magic numbers to renumber.

## When to use raw indices

Raw indices (`Int32`) are still useful for:

- Reading a single column — `try String.column(of: stmt, at: 0)` is shorter than threading a `ManagedIndex`.
- Re-reading the same parameter or column out of order.
- Code generators that already track positions.

## Topics

- ``ManagedIndex``
- ``Bindable/bind(to:value:at:)-static``
- ``Bindable/column(of:at:)-static``
