/// Global actor that serializes access to SQLite database operations.
///
/// This actor ensures thread-safe database operations by serializing all database
/// access through a single actor instance. Functions and types marked with
/// `@DatabaseActor` are isolated to this actor's execution context, preventing
/// concurrent access issues with SQLite.
///
/// SQLite has limited thread-safety guarantees, so this actor provides safe
/// concurrent access by ensuring operations are executed serially.
///
/// The following types and functions are isolated to this actor:
/// - ``Database`` and its methods (query, exec, transaction, etc.)
/// - ``DatabaseHandle`` and ``StatementHandle`` (resource lifecycle)
/// - ``Bindable`` bind/column operations
/// - Internal helpers such as ``check(_:db:is:)``
@globalActor public actor DatabaseActor: GlobalActor {
  public static let shared = DatabaseActor()
}
