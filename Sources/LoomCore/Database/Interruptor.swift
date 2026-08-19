import SQLite3
import os

/// Cross-thread interrupt channel for one SQLite connection.
///
/// `sqlite3_interrupt` is the one SQLite call that is safe to invoke from another thread on a
/// live connection, which is what makes cancellation support possible at all: statements run
/// synchronously on `DatabaseActor`, so the abort signal must come from off the actor.
///
/// The unfair lock is the library's single deliberate exception to the "no internal locking,
/// the actor serializes everything" rule. SQLite forbids closing a connection while
/// `sqlite3_interrupt` is running on it, and a cancellation handler runs on the cancelling
/// thread — outside the actor's serialization. Holding the lock across both the interrupt
/// (it only sets a flag) and `invalidate()` (called immediately before `sqlite3_close_v2`)
/// makes close and interrupt mutually exclusive.
final class Interruptor: Sendable {
  private struct State {
    var dbPtr: OpaquePointer?
    var owner: UInt64?
    var nextTicket: UInt64 = 0
  }

  private let state: OSAllocatedUnfairLock<State>

  init(dbPtr: OpaquePointer) {
    state = OSAllocatedUnfairLock(uncheckedState: State(dbPtr: dbPtr))
  }

  // Claims the channel for one operation. The returned ticket scopes later
  // `interrupt(ticket:)` calls, so a cancellation handler firing after its
  // operation finished can never abort a different task's statement.
  func acquire() -> UInt64 {
    state.withLockUnchecked { state in
      state.nextTicket += 1
      state.owner = state.nextTicket
      return state.nextTicket
    }
  }

  // Releases the channel if `ticket` still owns it.
  func release(_ ticket: UInt64) {
    state.withLockUnchecked { state in
      if state.owner == ticket {
        state.owner = nil
      }
    }
  }

  // Interrupts the connection only while `ticket` owns the channel and the
  // connection is still live.
  func interrupt(ticket: UInt64) {
    state.withLockUnchecked { state in
      guard state.owner == ticket, let dbPtr = state.dbPtr else { return }
      sqlite3_interrupt(dbPtr)
    }
  }

  // Unconditional interrupt; backs the public `Database/interrupt()`.
  func interrupt() {
    state.withLockUnchecked { state in
      guard let dbPtr = state.dbPtr else { return }
      sqlite3_interrupt(dbPtr)
    }
  }

  // Disconnects the pointer under the lock so no interrupt can race the
  // `sqlite3_close_v2` that follows.
  func invalidate() {
    state.withLockUnchecked { state in
      state.dbPtr = nil
    }
  }
}
