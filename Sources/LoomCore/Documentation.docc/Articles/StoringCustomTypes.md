# Storing Custom Types

How `Bindable` maps Swift types to SQLite storage, and how to extend it.

## Overview

The ``Bindable`` protocol is the single extension point for type-safe parameter binding and column extraction. Every type LoomCore supports — from `Int` to `Date` to your own `Codable` structs — conforms to ``Bindable`` and provides:

- `bind(to:value:at:)` — write a value to a parameter slot.
- `column(of:at:)` — read a value from a column.
- `asSQLLiteral()` — produce a literal SQL representation for debugging.
- `defaultSQLStorageType` — the SQL type to use in `CREATE TABLE`.

### Built-in conformances

| Swift type | SQLite storage | Notes |
| --- | --- | --- |
| `String` | TEXT | UTF-8, single quotes doubled in literals |
| `Int`, `Int32`, `Int64` | INTEGER | `Int` round-trips through `Int64` |
| `Float` | DOUBLE | Round-trips through `Double` — slight precision loss possible |
| `Double` | DOUBLE | Native |
| `Bool` | INTEGER (0/1) | Literal renders as `TRUE`/`FALSE` |
| `Data` | BLOB | Hex literals (`X'…'`) |
| `Date` | DOUBLE | Unix timestamp seconds since 1970, UTC |
| `TextDate` | TEXT | SQLite datetime text `YYYY-MM-DD HH:MM:SS.SSS`, UTC — for `CURRENT_TIMESTAMP`-style columns |
| `UUID` | BLOB | 16-byte raw bytes, **not** a TEXT string |
| `Optional<T>` | underlying or NULL | Reads NULL via column type check |
| `RawRepresentable` | derived from `RawValue` | The enum's raw type's storage |
| `Array`, `Dictionary` | TEXT (JSON) | JSON-encoded |
| `Codable` | TEXT (JSON) | JSON-encoded; you opt in by conforming to ``JSONBindable`` |

### Custom Codable types

Any `Codable` type can become ``Bindable`` by conforming to ``JSONBindable`` — no implementation needed:

```swift
struct Profile: Codable, JSONBindable {
  let displayName: String
  let avatarURL: URL?
  let preferences: [String: String]
}

try await db.exec(
  "CREATE TABLE accounts (id INTEGER PRIMARY KEY, profile TEXT)"
)

let profile = Profile(
  displayName: "Alice",
  avatarURL: URL(string: "https://example.com/a.png"),
  preferences: ["theme": "dark"]
)
try await db.exec("INSERT INTO accounts (profile) VALUES (\(profile))")
```

Encoding uses `JSONEncoder` and stores JSON TEXT, so stored values work directly with SQLite's JSON functions — `json_extract(profile, '$.displayName')`, the `->`/`->>` operators, `json_set`, and friends.

JSON storage is opt-in so it never competes with other storage strategies: a raw-value enum declared `enum Role: String, Codable, Bindable` keeps its raw-value storage (`'admin'`, not `'"admin"'`). Don't combine ``JSONBindable`` with a `RawRepresentable`-based ``Bindable`` conformance on one type.

### NULL handling

Non-optional ``Bindable`` types throw ``LoomError`` with code ``LoomCoreErrorCode/nullValue`` if the column contains NULL:

```swift
let names = try await db.query(raw: "SELECT name FROM accounts") { stmt, _ in
  try String.column(of: stmt, at: 0)  // throws if NULL
}
```

Use `Optional<T>` to handle NULL explicitly:

```swift
let avatarURLs = try await db.query(raw: "SELECT avatar_url FROM accounts") { stmt, _ in
  try Optional<String>.column(of: stmt, at: 0)  // nil if NULL
}
```

`Optional` checks `sqlite3_column_type == SQLITE_NULL` before delegating to the wrapped type.

### RawRepresentable enums

Enums backed by a ``Bindable`` raw type can be stored directly:

```swift
enum AccountState: Int, Bindable {
  case active = 0
  case suspended = 1
  case closed = 2
}

try await db.exec("INSERT INTO accounts (state) VALUES (\(AccountState.active))")
```

If a stored value doesn't map to a case (e.g. `state = 99`), extraction throws ``LoomError`` with code ``LoomCoreErrorCode/typeMappingFailed``.

### Writing your own Bindable

For types that don't fit Codable (e.g. you want to control storage layout), conform to ``Bindable`` directly. The contract is small enough to implement in a few lines — see `Bindable+UUID.swift` for a self-contained example that stores 16 raw bytes via `sqlite3_bind_blob`.

## Topics

- ``Bindable``
- ``JSONBindable``
- ``LoomError``
- ``LoomCoreErrorCode``
