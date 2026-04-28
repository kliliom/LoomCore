import Foundation
import SQLite3

extension Database {
  /// Base class for database services that respond to transaction lifecycle events.
  ///
  /// Services provide a modular way to add cross-cutting functionality to database operations,
  /// such as caching, change tracking, or validation. They receive callbacks at key points
  /// in the transaction lifecycle, allowing them to maintain state or perform side effects.
  ///
  /// Subclass this class to create custom services that need to coordinate with database
  /// transactions. Services are singleton per type within a database instance - calling
  /// ``Database/getService(_:)`` with the same type always returns the same instance.
  ///
  /// The following example demonstrates a simple logging service:
  ///
  ///     class LoggingService: Database.Service {
  ///       override func transactionDidCommit() {
  ///         print("Transaction committed successfully")
  ///       }
  ///     }
  ///
  ///     let logger = db.getService(LoggingService.self)
  ///
  /// - Important: All service methods are called on ``DatabaseActor``, ensuring thread-safe
  ///              access to the database and service state.
  @DatabaseActor
  open class Service {
    /// The database instance managing this service.
    ///
    /// This is a weak reference to prevent retain cycles. The database owns the service,
    /// so this reference becomes `nil` when the database is deallocated.
    public private(set) weak var database: Database?

    /// Creates a new service instance attached to the specified database.
    ///
    /// - Parameter database: The database instance that will manage this service's lifecycle.
    public required init(database: Database) {
      self.database = database
    }

    /// Called immediately before a transaction begins.
    ///
    /// Override this method to perform setup or validation before transaction execution.
    /// For example, you might initialize temporary state or validate preconditions.
    ///
    /// - Note: The ``database`` property is guaranteed to be non-nil when this is called.
    open func transactionWillBegin() {}

    /// Called immediately after a transaction commits successfully.
    ///
    /// Override this method to perform post-commit actions like cache updates, event
    /// notifications, or persistence of transaction metadata. This is only called if
    /// the transaction commits - it won't be called if the transaction rolls back.
    ///
    /// - Note: The ``database`` property is guaranteed to be non-nil when this is called.
    open func transactionDidCommit() {}

    /// Called immediately after a transaction rolls back.
    ///
    /// Override this method to clean up state or revert changes that were made during
    /// the failed transaction. This is called for both explicit rollbacks and rollbacks
    /// triggered by errors.
    ///
    /// - Note: The ``database`` property is guaranteed to be non-nil when this is called.
    open func transactionDidRollback() {}

    /// Called when the service is being shut down and removed from the database.
    ///
    /// Override this method to perform cleanup, release resources, or persist final state.
    /// This is called when ``Database/shutdownService(_:)`` is invoked.
    ///
    /// - Note: The ``database`` property may be `nil` if the database has already been closed.
    open func shutdown() {}
  }

  /// Retrieves or creates a singleton instance of the specified service type.
  ///
  /// Services follow a singleton pattern per type within each database instance. The first
  /// call to this method for a given service type creates and registers the service. Subsequent
  /// calls return the same instance.
  ///
  /// The following example demonstrates service retrieval:
  ///
  ///     let cache = db.getService(CacheService.self)
  ///     let sameCache = db.getService(CacheService.self)  // Returns the same instance
  ///
  /// - Parameter type: The service class type to retrieve or instantiate.
  /// - Returns: The singleton service instance for the specified type.
  public func getService<T: Service>(_ type: T.Type) -> T {
    guard let service = services[ObjectIdentifier(type)] as? T else {
      let service = T(database: self)
      services[ObjectIdentifier(type)] = service
      return service
    }

    return service
  }

  /// Shuts down and removes the specified service from the database.
  ///
  /// This method calls the service's ``Service/shutdown()`` method and then removes it
  /// from the service registry. After shutdown, calling ``getService(_:)`` with the same
  /// type will create a fresh service instance.
  ///
  /// - Parameter type: The service class type to shut down.
  public func shutdownService(_ type: Service.Type) {
    let removed = services.removeValue(forKey: ObjectIdentifier(type))
    removed?.shutdown()
  }

  /// Notifies all registered services that a transaction is about to begin.
  ///
  /// Called internally by ``transaction(kind:_:)`` before executing the transaction block.
  /// Invokes ``Service/transactionWillBegin()`` on each registered service.
  func signalTransactionWillBegin() {
    for (_, service) in services {
      service.transactionWillBegin()
    }
  }

  /// Notifies all registered services that a transaction has committed successfully.
  ///
  /// Called internally by ``transaction(kind:_:)`` after the `COMMIT` statement succeeds.
  /// Invokes ``Service/transactionDidCommit()`` on each registered service.
  func signalTransactionDidCommit() {
    for (_, service) in services {
      service.transactionDidCommit()
    }
  }

  /// Notifies all registered services that a transaction has been rolled back.
  ///
  /// Called internally by ``transaction(kind:_:)`` when an error occurs or `ROLLBACK` is executed.
  /// Invokes ``Service/transactionDidRollback()`` on each registered service.
  func signalTransactionDidRollback() {
    for (_, service) in services {
      service.transactionDidRollback()
    }
  }
}
