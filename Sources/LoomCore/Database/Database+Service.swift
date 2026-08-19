import Foundation
import SQLite3

extension Database {
  /// Base class for cross-cutting database services that hook into transaction lifecycle events.
  ///
  /// Services receive callbacks before a transaction begins, after a successful commit, and after
  /// a rollback, plus a final ``shutdown()`` when removed from the database. Each subclass is a
  /// singleton per ``Database`` — repeated calls to ``Database/getService(_:)`` for the same type
  /// return the same instance.
  ///
  /// ```swift
  /// struct TableChange {
  ///   let table: String
  /// }
  ///
  /// final class ChangeTracker: Database.Service {
  ///   private(set) var pendingChanges: [TableChange] = []
  ///   private var snapshot: [TableChange] = []
  ///
  ///   override func transactionWillBegin() {
  ///     snapshot = pendingChanges
  ///   }
  ///
  ///   override func transactionDidCommit() {
  ///     NotificationCenter.default.post(name: .init("databaseDidChange"), object: pendingChanges)
  ///     pendingChanges.removeAll()
  ///   }
  ///
  ///   override func transactionDidRollback() {
  ///     pendingChanges = snapshot
  ///   }
  /// }
  ///
  /// let tracker = await db.getService(ChangeTracker.self)
  /// ```
  ///
  /// All callbacks run on ``DatabaseActor``, so service state is serialized with database access
  /// without additional locking.
  @DatabaseActor
  open class Service {
    /// Owning database, weakly held to avoid a retain cycle with the service registry.
    ///
    /// Becomes `nil` once the ``Database`` is deallocated. Lifecycle callbacks other than
    /// ``shutdown()`` are guaranteed to fire while this reference is still alive.
    public private(set) weak var database: Database?

    /// Creates a service bound to `database` and registered as its singleton for this type.
    public required init(database: Database) {
      self.database = database
    }

    /// Invoked before each transaction body executes.
    ///
    /// Override to capture preconditions or seed per-transaction state that
    /// ``transactionDidRollback()`` can later restore.
    open func transactionWillBegin() {}

    /// Invoked after a transaction commits successfully.
    ///
    /// Override to publish accumulated changes, refresh caches, or notify listeners. Not called
    /// when the transaction rolls back.
    open func transactionDidCommit() {}

    /// Invoked after a transaction rolls back, whether explicitly or because the body threw.
    ///
    /// Override to discard tentative state captured during ``transactionWillBegin()``.
    open func transactionDidRollback() {}

    /// Invoked once when ``Database/shutdownService(_:)`` removes the service.
    ///
    /// ``database`` may already be `nil` if the owning ``Database`` has been deallocated, so
    /// avoid issuing further queries from this method.
    open func shutdown() {}
  }

  /// Returns the singleton instance of `type` for this database, creating it on first access.
  ///
  /// ```swift
  /// final class QueryCache: Database.Service { /* ... */ }
  ///
  /// let cache = await db.getService(QueryCache.self)
  /// let same = await db.getService(QueryCache.self)  // identical instance
  /// ```
  public func getService<T: Service>(_ type: T.Type) -> T {
    guard let service = services[ObjectIdentifier(type)] as? T else {
      let service = T(database: self)
      services[ObjectIdentifier(type)] = service
      return service
    }

    return service
  }

  /// Removes `type` from the database after invoking its ``Service/shutdown()`` callback.
  ///
  /// A subsequent call to ``getService(_:)`` for the same type allocates a fresh instance.
  public func shutdownService(_ type: Service.Type) {
    let removed = services.removeValue(forKey: ObjectIdentifier(type))
    removed?.shutdown()
  }

  /// Notifies all registered services that a transaction has begun, returning the
  /// participating set.
  ///
  /// Called internally by ``transaction(kind:_:)`` after the `BEGIN` statement succeeds.
  /// The returned snapshot is passed to the matching commit/rollback signal so a service
  /// registered while the transaction is in flight never receives an unpaired terminal
  /// callback.
  func signalTransactionWillBegin() -> [Service] {
    let participants = Array(services.values)
    for service in participants {
      service.transactionWillBegin()
    }
    return participants
  }

  /// Notifies the participating services that the transaction has committed successfully.
  ///
  /// Called internally by ``transaction(kind:_:)`` after the `COMMIT` statement succeeds.
  /// Participants shut down while the transaction was in flight are skipped: `shutdown()`
  /// is a service's final callback.
  func signalTransactionDidCommit(to participants: [Service]) {
    for service in participants where isRegistered(service) {
      service.transactionDidCommit()
    }
  }

  /// Notifies the participating services that the transaction has been rolled back.
  ///
  /// Called internally by ``transaction(kind:_:)`` after the `ROLLBACK` statement succeeds.
  /// Participants shut down while the transaction was in flight are skipped: `shutdown()`
  /// is a service's final callback.
  func signalTransactionDidRollback(to participants: [Service]) {
    for service in participants where isRegistered(service) {
      service.transactionDidRollback()
    }
  }

  /// Whether `service` is still this database's registered instance for its type. Instance
  /// identity, not type: a same-type instance registered mid-transaction is not the
  /// participant that received `transactionWillBegin()`.
  private func isRegistered(_ service: Service) -> Bool {
    services[ObjectIdentifier(type(of: service))] === service
  }
}
