# Querying JSON

Extract, filter, modify, build, and iterate JSON documents with typed expressions over SQLite's JSON functions.

## Overview

SQLite ships a complete JSON toolkit — `json_extract`, the `->`/`->>` operators, `json_set`, aggregates, and the `json_each`/`json_tree` table-valued functions — and every OS version LoomCore supports includes it. This article shows the typed expression DSL over those functions. For how JSON gets *into* a column in the first place, see <doc:StoringCustomTypes> and ``JSONBindable``.

The examples below assume a table of users whose `profile` column holds a JSON document such as `{"displayName":"Alice","age":30,"address":{"city":"Vienna"},"tags":["swift","sql"]}`.

### JSON paths

Every function that addresses part of a document takes a ``JSONPath`` — `$` is the document root, `$.address.city` a nested member, `$.tags[0]` an array element, and `$."key with spaces"` a quoted key. Paths are usually written as string literals:

```swift
let profile = ColumnExpression<String>("profile")
let city = profile.jsonValue("$.address.city", as: String.self)
```

Paths render into the SQL as single-quoted literals, not bound parameters. This is deliberate: SQLite matches an expression index on `json_extract("profile", '$.age')` only when the path is a literal token, so binding paths would silently turn indexed JSON lookups into table scans. The trade-offs are that a path is inlined like an identifier — treat it as trusted input, like a column name — and that statements differing only in their paths are distinct entries in the prepared-statement cache.

### Extracting values

Extraction states the expected Swift type up front, because a JSON node can decode to any storage class and LoomCore's column reads are strictly checked:

```swift
let profile = ColumnExpression<String>("profile")

let age = profile.jsonValue("$.age", as: Int.self)  // ("profile"->>'$.age')
let name = profile.jsonExtract("$.displayName", as: String.self)  // JSON_EXTRACT(…)

let adults = try await db.query("SELECT \(name) FROM users WHERE \(age >= 18)") { stmt, _ in
  try String?.column(of: stmt, at: 0)
}
```

Results are optional — a NULL document or a path that selects nothing yields NULL. ``Expression/jsonValue(_:as:)`` (the `->>` operator) returns plain SQL values; ``Expression/jsonFragment(_:)`` (the `->` operator) returns the selected node *as JSON text*, so string nodes keep their quotes and the result chains:

```swift
let profile = ColumnExpression<String>("profile")
let city = profile.jsonFragment("$.address").jsonValue("$.city", as: String.self)
```

Inspect documents with ``Expression/jsonType(_:)`` (type name at a path), ``Expression/jsonValid()``, and ``Expression/jsonArrayLength(_:)``; locate the syntax error in a broken document with ``Expression/jsonErrorPosition()`` (SQLite 3.42+, iOS 17/macOS 14).

### Modifying documents

``Expression/jsonSet(_:_:)`` overwrites or creates, ``Expression/jsonInsert(_:_:)`` only creates, and ``Expression/jsonReplace(_:_:)`` only overwrites. Each takes ``JSONAssignment`` pairs, and the choice of factory matters: SQLite treats a bound TEXT argument as a JSON *string*, so a nested document must be wrapped.

```swift
struct Address: Codable, JSONBindable {
  let city: String
}

let profile = ColumnExpression<String>("profile")
try await db.exec(
  """
  UPDATE users SET profile = \(profile.jsonSet(
    .value("$.displayName", "Alice"),
    .json("$.address", Address(city: "Vienna"))
  ))
  """
)
```

`.value` binds scalars — numbers, strings, booleans — directly; `.json` wraps the bound text in `JSON(?)` so a ``JSONBindable`` nests as a real object rather than a string. Assigning a `nil` optional through `.value` stores JSON `null`.

Delete nodes with ``Expression/jsonRemove(_:_:)``, and merge whole documents with ``Expression/jsonPatch(_:)`` (RFC 7396: patch keys overwrite, `null` removes). Unlike `jsonSet` values, a `jsonPatch` argument needs no wrapping — both sides are parsed as JSON, so passing a ``JSONBindable`` directly is exactly right.

### Building and aggregating

``jsonArray(_:)`` and ``jsonObject(_:)`` construct documents in the SELECT list; ``Expression/jsonGroupArray()`` and ``jsonGroupObject(name:value:)`` aggregate grouped rows. All four are non-optional: empty input yields `'[]'` or `'{}'`, and NULL inputs become JSON `null` members.

```swift
let author = ColumnExpression<String>("author")
let title = ColumnExpression<String>("title")
let shelves = try await db.query(
  "SELECT \(author), \(title.jsonGroupArray()) FROM books GROUP BY \(author)"
) { stmt, _ in
  (try String.column(of: stmt, at: 0), try String.column(of: stmt, at: 1))
}
```

The TEXT-is-a-string rule applies here too: to nest a column that already holds JSON, wrap it — `jsonArray(tags.json())`, not `jsonArray(tags)`.

### Iterating with JSON_EACH and JSON_TREE

``JSONEach`` yields one row per element of an array or object; ``JSONTree`` recurses into nested containers. Both are FROM-clause fragments — interpolate them after the tables and read rows through their typed column handles:

```swift
let userID = ColumnExpression<Int64>("id", of: "users")
let profile = ColumnExpression<String>("profile", of: "users")
let tag = JSONEach(profile, "$.tags")

// Users tagged "swift" — one row per (user, tag) pair, filtered.
let swiftUsers = try await db.query(
  "SELECT \(userID) FROM users, \(tag) WHERE \(tag.value(as: String.self) == "swift")"
) { stmt, _ in
  try Int64.column(of: stmt, at: 0)
}
```

`key`, `value`, and `atom` take `as:` because their storage class varies per row (array keys are integers, object keys are strings); `type`, `id`, `fullkey`, `path` — and `parent` on ``JSONTree`` — are fixed. Two things to watch: qualify your own columns when names collide (`json_each` exposes its own `id`), and pass `alias:` when the same function appears twice in one query.

### JSONB

SQLite 3.45 added JSONB, a compact binary encoding that skips re-parsing on every access. It ships with iOS 18, macOS 15, macCatalyst 18, tvOS 18, watchOS 11, and visionOS 2, so the `jsonb`-prefixed variants — ``Expression/jsonb()``, ``Expression/jsonbSet(_:_:)``, ``jsonbArray(_:)``, and friends — are annotated `@available` for those versions and return `Data` (BLOB) instead of `String`.

```swift
let profile = ColumnExpression<String>("profile")
if #available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
  try await db.exec("UPDATE users SET profile = \(profile.jsonb())")
}
```

Every text-level function accepts JSONB input transparently on those OS versions, so a column can be migrated to JSONB without touching the queries that read it — with one exception: the one-argument ``Expression/jsonValid()`` accepts only JSON text and reports JSONB as invalid. Validate migrated or mixed-storage columns with ``Expression/jsonValid(_:)``, e.g. `data.jsonValid([.json, .jsonb])`. JSONB is an internal SQLite format: store it and query it, but do not parse the bytes outside SQLite. There is no `jsonb_each` — ``JSONEach`` already accepts JSONB input.

## Topics

- ``JSONPath``
- ``JSONBindable``
- ``JSONExtract``
- ``JSONAccessExpression``
- ``JSONAssignment``
- ``JSONModify``
- ``JSONEach``
- ``JSONTree``
