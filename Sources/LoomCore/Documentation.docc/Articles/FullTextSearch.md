# Full-Text Search

Match, rank, and excerpt text with typed expressions over SQLite's FTS5 extension.

## Overview

SQLite ships FTS5 — virtual tables with a full-text index, the `MATCH` operator, `bm25` relevance scoring, and the `snippet`/`highlight` auxiliary functions — and every OS version LoomCore supports includes it. This article shows the typed expression DSL over those features.

Creating the index itself stays plain SQL, in line with LoomCore not being an ORM:

```swift
try await db.exec(raw: "CREATE VIRTUAL TABLE articles USING fts5(title, body)")
```

An ``FTS5Table`` then names that table for the DSL. Pass `columns` (in declaration order) when you plan to use ``FTS5Table/snippet(column:prefix:suffix:ellipsis:maxTokens:)`` or ``FTS5Table/highlight(column:prefix:suffix:)``, which address columns by name; matching and ranking work without it.

```swift
let articles = FTS5Table("articles", columns: ["title", "body"])
```

### Matching

``FTS5Table/match(_:)->MatchExpression<R>`` builds the `MATCH` predicate. The query string uses FTS5's own syntax — bare tokens are AND-ed, `"quoted text"` is a phrase, `title : swift` filters a column — and is bound as a parameter, so it can never escape the `MATCH` operand into SQL:

```swift
let articles = FTS5Table("articles")
let userInput = "swift database"

let hits = try await db.query(
  "SELECT title FROM articles WHERE \(articles.match(userInput))"
) { stmt, _ in
  try String.column(of: stmt, at: 0)
}
```

Binding is the opposite choice from ``JSONPath``, which inlines its paths so SQLite can match expression indexes; no such optimization applies to `MATCH`, and binding means statements differing only in search text share one prepared-statement cache entry. The cost of accepting raw syntax is that a malformed query — an unclosed quote, a dangling `AND` — only fails when SQLite executes the statement, surfacing as a thrown ``LoomError``.

> Important: Binding prevents SQL injection; it does not sandbox the FTS5 query language itself. A whole-table match hands the searcher FTS5's full grammar, including column filters over **every** indexed column — `secret : guess` probes a column your UI never displays, and `*` prefixes narrow guesses further. Pass raw user input through only when every indexed column is meant to be user-searchable. Otherwise route user text through ``FTS5Query/phrase(_:fromStart:)`` or ``FTS5Query/prefix(_:fromStart:)`` (metacharacters are inert there), scope the search with an explicit ``FTS5Query/column(_:_:)`` filter or a single-column `match(_:)` (an inner filter cannot widen a column-scoped match), and keep text that must never be searchable out of the FTS5 index entirely.

A single column can be matched directly through `match(_:)` on a `String`-typed ``ColumnExpression``:

```swift
let title = ColumnExpression<String>("title")
let titled = try await db.query("SELECT title FROM articles WHERE \(title.match("swift"))") { stmt, _ in
  try String.column(of: stmt, at: 0)
}
```

A match predicate composes with `&&` only. It also type-checks under `||` and prefix `!`, but SQLite rejects `MATCH` in those positions at execution — express alternatives and exclusions inside the query itself with ``FTS5Query/or(_:)`` and ``FTS5Query/not(_:)``.

### The query builder

For queries assembled in code, ``FTS5Query`` renders FTS5 syntax that is correct by construction. Phrase text is always quoted with embedded quotes doubled, so it is treated as data — `*`, `^`, `:`, and operators inside it have no effect:

```swift
let articles = FTS5Table("articles")

// ("swift concurrency" AND "actor"*) — a phrase requires adjacent tokens,
// a prefix matches "actor", "actors", "actor-isolated", …
let query = FTS5Query.phrase("swift concurrency").and(.prefix("actor"))

let hits = try await db.query(
  "SELECT title FROM articles WHERE \(articles.match(query))"
) { stmt, _ in
  try String.column(of: stmt, at: 0)
}
```

``FTS5Query/phrase(_:fromStart:)`` and ``FTS5Query/prefix(_:fromStart:)`` are the leaves (`fromStart` prepends `^`, matching only at the start of a column); ``FTS5Query/and(_:)``, ``FTS5Query/or(_:)``, and ``FTS5Query/not(_:)`` combine them, always parenthesizing so precedence never depends on FTS5's grammar. ``FTS5Query/near(_:distance:)`` requires phrases to appear close together, and ``FTS5Query/column(_:_:)`` / ``FTS5Query/columns(_:_:)`` restrict a sub-query to specific columns:

```swift
// {"title" "summary"} : (NEAR("swift" "database", 5) OR "sqlite")
let query = FTS5Query.columns(
  ["title", "summary"],
  .near(["swift", "database"], distance: 5).or(.phrase("sqlite"))
)
```

The rendered query is bound exactly like a raw string, so the two entry points mix freely.

### Ranking

Within a full-text query, the hidden ``FTS5Table/rank`` column carries each row's relevance score. Scores are negative and lower is more relevant, so ascending `ORDER BY` returns the best matches first:

```swift
let articles = FTS5Table("articles")
let best = try await db.query(
  "SELECT title FROM articles WHERE \(articles.match("swift")) ORDER BY \(articles.rank)"
) { stmt, _ in
  try String.column(of: stmt, at: 0)
}
```

Outside a `MATCH` statement the column is NULL, hence its `Double?` type. ``FTS5Table/bm25(weights:)`` exposes the same scoring function with per-column weights — one weight per indexed column, in declaration order:

```swift
let articles = FTS5Table("articles", columns: ["title", "body"])

// Matches in the title count ten times as much as matches in the body.
let ranked = try await db.query(
  "SELECT title FROM articles WHERE \(articles.match("swift")) ORDER BY \(articles.bm25(weights: [10, 1]))"
) { stmt, _ in
  try String.column(of: stmt, at: 0)
}
```

### Snippets and highlights

``FTS5Table/snippet(column:prefix:suffix:ellipsis:maxTokens:)`` extracts a fragment of matched text — up to `maxTokens` tokens (at most 64) around the best match, with each matched token wrapped in `prefix`/`suffix` and truncation marked by `ellipsis`. ``FTS5Table/highlight(column:prefix:suffix:)`` returns the column's full text with the same marking:

```swift
let articles = FTS5Table("articles", columns: ["title", "body"])

let results = try await db.query(
  """
  SELECT
    \(articles.highlight(column: "title", prefix: "<b>", suffix: "</b>")),
    \(articles.snippet(column: "body", prefix: "<b>", suffix: "</b>", ellipsis: "…", maxTokens: 12))
  FROM articles WHERE \(articles.match("swift")) ORDER BY \(articles.rank)
  """
) { stmt, _ in
  (try String?.column(of: stmt, at: 0), try String?.column(of: stmt, at: 1))
}
```

SQLite identifies these columns by positional index; LoomCore resolves the name against the table's declared `columns`, so the list must include every column you excerpt. Both functions return NULL — hence `String?` — when the underlying column value is NULL. Omitting `column:` from `snippet` lets FTS5 pick the most relevant column itself.

> Warning: The declared `columns` order is load-bearing and never checked against the live table. If a migration reorders or inserts a column and the Swift declaration isn't updated, the name resolves to a valid but *wrong* index and every snippet and highlight silently excerpts the wrong column — no error is raised. Pin the declaration to the live schema with ``FTS5Table/verifyColumns(on:)`` in an integration test or at startup.

## Topics

- ``FTS5Table``
- ``FTS5Query``
- ``MatchExpression``
- ``BM25``
- ``Snippet``
- ``Highlight``
