# LoomCore

A type-safe SQLite wrapper for Swift 6+ using actor isolation for thread safety.

## Features

- 🛡️ **Type-Safe Bindings** - `Bindable` protocol for compile-time-checked parameter binding and column extraction
- 💉 **Safe Interpolation** - SQL string interpolation with automatic parameter binding (no SQL injection)
- 🧵 **Actor Isolation** - All database access serialized through `DatabaseActor` (no race conditions)
- 🔁 **Transactions** - Async atomic blocks with deferred/immediate/exclusive lock modes, automatic rollback, and `SAVEPOINT`-based nesting
- 🚦 **Transaction Gating** - Operations outside an in-flight transaction wait until it commits or rolls back — transaction bodies can suspend freely
- 🧮 **Expressions** - Operator overloading for building SQL expressions in Swift
- 🗂️ **Codable Support** - Automatic JSON encoding/decoding for `Codable` types
- 🪝 **Service Hooks** - Transaction lifecycle callbacks for cache invalidation and side effects
- 🗃️ **Statement Caching** - Prepared statements cached automatically inside `cached { }` scopes (per task tree)

## Installation

Add LoomCore to your Swift package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/kliliom/loom-core.git", from: "1.0.0")
]
```

## Quick Start

```swift
import LoomCore

let db = try await Database.openInMemory()

try await db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)")

let name = "Alice"
let age = 30
try await db.exec("INSERT INTO users (name, age) VALUES (\(name), \(age))")

let users = try await db.query("SELECT name, age FROM users WHERE age > \(25)") { stmt, _ in
    let name = try String.column(of: stmt, at: 0)
    let age = try Int.column(of: stmt, at: 1)
    return (name, age)
}
```

## Core Concepts

### Actor Isolation

`Database` is `@DatabaseActor` isolated — all operations serialize through a global actor, so concurrent access is safe by construction. You cannot call `Database` methods from arbitrary async contexts without hopping to the actor first.

### Index Conventions

SQLite has asymmetric indexing — LoomCore preserves this:

- **Parameter indices are 1-based** (`bind(to: stmt, at: 1)` — leftmost `?`)
- **Column indices are 0-based** (`column(of: stmt, at: 0)` — leftmost column)

Use `ManagedIndex` to avoid mistakes when binding or reading multiple values (see below).

### Safe by Default

String interpolation defaults to `.bind` mode — values are sent as bound parameters, never concatenated into SQL. Only use `.raw` mode for trusted SQL identifiers (table/column names from your own code), never for user input.

## Opening a Database

```swift
// In-memory (testing, scratch work)
let db = try await Database.openInMemory()

// File-based
let url = URL(fileURLWithPath: "/path/to/database.sqlite")
let db = try await Database.open(url: url)
```

## Queries

### String Interpolation (recommended)

Values inside `\(...)` are automatically bound as parameters:

```swift
let minAge = 21
let users = try await db.query("SELECT name FROM users WHERE age > \(minAge)") { stmt, _ in
    try String.column(of: stmt, at: 0)
}
```

### Raw SQL with Manual Binding

```swift
let users = try await db.query(
    raw: "SELECT name, email FROM users WHERE status = ?",
    binder: { stmt, index in
        try "active".bind(to: stmt, at: &index)
    },
    stepper: { stmt, index, stop in
        let name = try String.column(of: stmt, at: &index)
        let email = try String.column(of: stmt, at: &index)
        return User(name: name, email: email)
    }
)
```

### Early Termination

Set `stop = true` in the stepper to stop iterating:

```swift
let firstMatch = try await db.query("SELECT name FROM users") { stmt, stop in
    let name = try String.column(of: stmt, at: 0)
    if name == "TargetName" {
        stop = true
    }
    return name
}
```

## Writes

```swift
// DDL
try await db.exec("CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT)")

// INSERT / UPDATE / DELETE with interpolation
try await db.exec("INSERT INTO items (name) VALUES (\(name))")

// Last inserted rowid — captures the ROWID of the last insert inside the block
let id = try await db.lastInsertedRowID {
    try await db.exec("INSERT INTO items (name) VALUES (\(name))")
}
```

## Transactions

Transactions commit on success and roll back on error. The body receives the database it runs on and may suspend freely — atomicity is preserved across `await`s:

```swift
try await db.transaction { db in
    try await db.exec("INSERT INTO users (name, age) VALUES ('Bob', 25)")
    try await db.exec("INSERT INTO users (name, age) VALUES ('Carol', 28)")
}
```

With a specific lock mode:

```swift
try await db.transaction(kind: .immediate) { db in
    // ...
}
```

While a transaction is in flight — even while suspended at an `await` — operations from tasks outside it wait until it commits or rolls back. Structured child tasks (`async let`, task groups) and `Task {}` run inside the transaction (an un-awaited `Task {}` that outlives the body races the commit); `Task.detached` does not and waits like any outside caller.

Nested `transaction` calls open a `SAVEPOINT` scope: a normal return releases the savepoint into the enclosing transaction, and a throw rolls back to the savepoint — leaving the enclosing transaction's work intact — and rethrows. The `kind:` parameter is ignored for nested calls.

## Type Bindings

`Bindable` types can be bound as parameters and extracted as columns. Built-in support for:

- `String`, `Int`, `Double`, `Float`, `Bool`
- `Data` (BLOB)
- `UUID` (stored as TEXT)
- `Date` (stored as Unix timestamp REAL)
- `Optional<T>` (NULL handling)
- `RawRepresentable` enums
- `Array`, `Dictionary` (JSON-encoded)
- `Codable` types (JSON-encoded as TEXT)

### Optional / NULL

```swift
let email: String? = nil
try await db.exec("INSERT INTO users (name, email) VALUES (\(name), \(email))")

let result = try await db.query("SELECT email FROM users") { stmt, _ in
    try Optional<String>.column(of: stmt, at: 0)
}
```

### Codable

```swift
struct Metadata: Codable {
    let createdAt: Date
    let tags: [String]
}

let meta = Metadata(createdAt: Date(), tags: ["swift", "database"])
try await db.exec("INSERT INTO items (metadata) VALUES (\(meta))")

let retrieved = try await db.query("SELECT metadata FROM items") { stmt, _ in
    try Metadata.column(of: stmt, at: 0)
}
```

## Managed Indices

For multi-column queries, `ManagedIndex` auto-increments after each bind/column call so you don't have to track positions manually:

```swift
let users = try await db.query(
    raw: "SELECT id, name, email, age FROM users WHERE status = ?",
    binder: { stmt, index in
        try "active".bind(to: stmt, at: &index)        // -> param 1
    },
    stepper: { stmt, index, stop in
        let id = try Int.column(of: stmt, at: &index)         // -> column 0
        let name = try String.column(of: stmt, at: &index)    // -> column 1
        let email = try String.column(of: stmt, at: &index)   // -> column 2
        let age = try Int.column(of: stmt, at: &index)        // -> column 3
        return User(id: id, name: name, email: email, age: age)
    }
)
```

## SQL Building

### Statement Composition

`SQLStatement` values can be combined:

```swift
var stmt: SQLStatement = "SELECT * FROM users"
stmt += "WHERE age > \(25)"
let combined = stmt1 + stmt2
```

### Raw Mode for Identifiers

Use `.raw` mode for SQL identifiers from trusted sources (your own configuration), never user input:

```swift
let table = "users"
let column = "email"

let stmt: SQLStatement = "SELECT \(column, mode: .raw) FROM \(table, mode: .raw)"
```

> ⚠️ Never use `.raw` with user input — it bypasses parameter binding and is a SQL injection risk.

## Expressions

Bindable types support SQL operators directly in Swift:

```swift
let predicate = age > 21 && status == "active"   // Expression<Bool>
let total     = (price * quantity) + tax          // Expression<Double>
```

Aggregate and scalar functions: `count`, `sum`, `length`, `upper`, `lower`, `trim`, `substring`, `concat`, `groupConcat`, `ifNull`, `cast`.

## Services

Subclass `Database.Service` to hook into transaction lifecycle events:

```swift
class CacheInvalidationService: Database.Service {
    override func transactionDidCommit() {
        cache.clear()
    }

    override func transactionDidRollback() {
        // ...
    }
}

let service = db.getService(CacheInvalidationService.self)
```

Services are singletons per `Database` instance and per type. Lifecycle hooks fire only for the outermost physical transaction — nested `SAVEPOINT` scopes do not trigger them. The participating set is fixed when the transaction begins; a service registered mid-transaction receives callbacks starting with the next transaction.

## Requirements

- Swift 6.0+
- iOS 16+, macCatalyst 16+, macOS 13+, tvOS 16+, visionOS 1+, watchOS 9+

## Testing

LoomCore uses Swift Testing:

```bash
swift test
```

## Acknowledgements

Portions of this project — including documentation and tests — were developed with the assistance of [Claude Code](https://claude.com/claude-code).

## License

This project is licensed under the MIT License.
