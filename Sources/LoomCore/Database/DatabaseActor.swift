///  Global actor that serializes all SQLite access in LoomCore.
///
/// SQLite's threading model requires careful synchronization. `DatabaseActor` provides this
/// guarantee by isolating every database-touching operation to a single actor, so the compiler
/// enforces serialization at call sites rather than relying on runtime locks.
///
/// Annotate types or methods with `@DatabaseActor` to opt into this isolation. Calls from
/// non-isolated contexts must hop to the actor with `await`.
///
/// ```swift
/// @DatabaseActor
/// func loadActiveUsers(from db: Database) async throws -> [User] {
///   try await db.query("SELECT id, name FROM users WHERE active = \(true)") { row in
///     User(id: try row.column(at: 0), name: try row.column(at: 1))
///   }
/// }
///
/// Task {
///   let users = try await loadActiveUsers(from: db)
/// }
/// ```
///
/// ## Isolated surface
///
/// - ``Database`` and its methods (query, exec, transaction, …)
/// - ``DatabaseHandle`` and ``StatementHandle`` resource lifecycles
/// - ``Bindable`` bind and column operations
/// - Internal helpers such as `check(_:db:is:)`
@globalActor public actor DatabaseActor: GlobalActor {
  public static let shared = DatabaseActor()
}
