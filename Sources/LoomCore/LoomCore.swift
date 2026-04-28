/// LoomCore — type-safe, actor-isolated SQLite for Swift.
///
/// Wraps SQLite directly without ORM abstractions, closing off unsafe edges
/// (string concatenation, manual binding, raw pointers, threading) through
/// the type system and `@DatabaseActor` isolation.
