# Safe SQL Interpolation

When `\(value)` becomes a parameter, when it becomes literal text, and how to keep injection-prone surfaces small.

## Overview

LoomCore uses Swift's string interpolation as its primary SQL-construction API. Every interpolated value defaults to **`.bind` mode** — it is added to the statement as a parameter (`?`) and its value is bound at execution time. This is the safe path; you cannot accidentally concatenate user input into the SQL text.

```swift
let user = "Alice'; DROP TABLE users; --"
try await db.exec("INSERT INTO users (name) VALUES (\(user))")
// SQL: "INSERT INTO users (name) VALUES (?)"
// Bound: "Alice'; DROP TABLE users; --"
```

The malicious payload becomes a literal string value in the database. There is no way to break out of the parameter binding.

### Raw mode

Some things cannot be parameters — table names, column names, SQL keywords. For these, opt in to `.raw` mode:

```swift
let table = "users"  // from your own configuration, NOT user input
try await db.exec("SELECT * FROM \(table, mode: .raw) WHERE active = \(true)")
// SQL: "SELECT * FROM users WHERE active = ?"
```

`.raw` skips parameter binding and pastes the value directly into the SQL string. This is exactly the surface SQL injection lives on.

> Warning: Never pass untrusted input through `.raw`. If user input determines a table or column name, validate it against an allowlist of known names before using `.raw`, or use ``ColumnExpression`` which always quotes identifiers safely.

### ColumnExpression — the safe identifier path

When you need to refer to a column by name, ``ColumnExpression`` is preferable to `.raw`:

```swift
let nameColumn = ColumnExpression<String>("name")
let userEmail  = ColumnExpression<String>("email", of: "users")

try await db.query("SELECT \(nameColumn) FROM users") { stmt, _ in
  try String.column(of: stmt, at: 0)
}
```

`ColumnExpression` always renders quoted identifiers (`"name"`, `"users"."email"`), escapes embedded double quotes by doubling, and rejects empty or NUL-containing names at construction. This makes reserved words like `order` and identifiers with spaces safe to use without special handling.

### JSON paths — literal by design

``JSONPath`` values (the `"$.name"` arguments of the JSON expressions) render as single-quoted, quote-doubled literals rather than bound parameters — the same treatment as `LIKE`'s `ESCAPE` operand. SQLite matches an expression index on `json_extract("col", '$.a')` only when the path is a literal token, so binding it would silently disable indexed JSON lookups. The doubling makes breaking out of the literal impossible, but a path still selects which node is read — treat it like a column name, not user input.

### Composing statements

``SQLStatement`` values can be combined while preserving parameter ordering:

```swift
let minAge = 18

var stmt: SQLStatement = "SELECT * FROM users"
stmt += "WHERE age > \(minAge)"
stmt += "ORDER BY name"
```

Each fragment carries its own binders; concatenation appends them in order. There is no parameter-renumbering to worry about.

## Topics

- ``SQLStatement``
- ``SQLBuilder``
- ``SQLBuilder/AppendMode``
- ``ColumnExpression``
