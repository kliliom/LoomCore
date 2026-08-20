# ``LoomCore``

A type-safe SQLite wrapper for Swift 6+ built on actor isolation.

## Overview

LoomCore is a thin wrapper around SQLite that closes off SQLite's unsafe edges with Swift's type system and a global actor. It is **not** an ORM — there is no schema generation, no migration system, and no relationship management. What you get is:

- **Safe-by-default SQL** — string interpolation always binds parameters; raw mode is opt-in for trusted identifiers.
- **Race-free access** — every `sqlite3_*` call is serialized through ``DatabaseActor``.
- **Type-safe bindings** — the ``Bindable`` protocol drives parameter binding and column extraction with compile-time checks.
- **Composable expressions** — operators and functions on ``Expression`` build typed SQL fragments without string concatenation.

If you have used SQLite directly from C, you will recognize the model. If you are coming from an ORM, expect to write more SQL — and to have more control over what runs.

```swift
import LoomCore

let db = try await Database.openInMemory()
try await db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)")

let name = "Alice"
try await db.exec("INSERT INTO users (name, age) VALUES (\(name), \(30))")

let users = try await db.query("SELECT name, age FROM users WHERE age > \(25)") { stmt, _ in
  let name = try String.column(of: stmt, at: 0)
  let age = try Int.column(of: stmt, at: 1)
  return (name, age)
}
```

## Topics

### Tutorials

Walkthroughs that build small but realistic apps end-to-end.

- <doc:tutorials/LoomCore>

### Articles

Concept-level explanations of how LoomCore is put together.

- <doc:IndexConventions>
- <doc:SafeInterpolation>
- <doc:ConcurrencyModel>
- <doc:StoringCustomTypes>
- <doc:QueryingJSON>
- <doc:FullTextSearch>
- <doc:TransactionsAndServices>

### Database

- ``Database``
- ``DatabaseActor``
- ``DatabaseHandle``
- ``StatementHandle``
- ``TransactionKind``

### Statements and Interpolation

- ``SQLStatement``
- ``SQLBuilder``

### Bindings and Indices

- ``Bindable``
- ``JSONBindable``
- ``TextDate``
- ``ManagedIndex``

### Expressions

- ``Expression``
- ``ColumnExpression``
- ``BinaryOperation``
- ``UnaryOperation``
- ``InExpression``
- ``LikeExpression``
- ``CastExpression``
- ``IfNullExpression``

### Functions

- ``Function``
- ``Concat``
- ``GroupConcat``
- ``Locate``
- ``Substring``
- ``Trim``
- ``Length``
- ``Lower``
- ``Upper``
- ``Avg``
- ``Sum``
- ``Count``
- ``Min``
- ``Max``

### JSON

- ``JSONPath``
- ``JSONExtract``
- ``JSONAccessExpression``
- ``JSONType``
- ``JSONValid``
- ``JSONErrorPosition``
- ``JSONArrayLength``
- ``JSONAssignment``
- ``JSONModify``
- ``JSONRemove``
- ``JSONPatch``
- ``JSONConversion``
- ``JSONArray``
- ``JSONObject``
- ``JSONGroupArray``
- ``JSONGroupObject``
- ``TableValuedFunction``
- ``JSONEach``
- ``JSONTree``
- ``jsonArray(_:)``
- ``jsonbArray(_:)``
- ``jsonObject(_:)``
- ``jsonbObject(_:)``
- ``jsonGroupObject(name:value:)``
- ``jsonbGroupObject(name:value:)``

### Full-Text Search

- ``FTS5Table``
- ``FTS5Query``
- ``MatchExpression``
- ``BM25``
- ``Snippet``
- ``Highlight``

### Errors

- ``LoomError``
- ``LoomError/ErrorCode``
- ``LoomCoreErrorCode``
- ``SQLiteResultCode``
