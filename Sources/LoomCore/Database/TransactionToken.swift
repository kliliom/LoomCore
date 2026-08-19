/// Identity of an open transaction scope, carried through the task tree.
///
/// Every transaction scope — an outermost `BEGIN` as well as a nested `SAVEPOINT` — gets its
/// own token. ``Database/transaction(kind:_:)`` binds the token as a task-local around the
/// body, so operations issued from the body (including `async let` and task-group children,
/// which inherit task-locals) can be recognized as belonging to the transaction and pass the
/// gate that suspends everyone else.
///
/// `parent` records the token that was current when this scope opened. Walking the chain lets
/// an operation match an *enclosing* scope, which covers two cases:
/// - Cross-database nesting: a transaction on database B opened inside a transaction on
///   database A rebinds the task-local, but operations on A inside B's body still match A's
///   token through the chain.
/// - Same-database savepoints: sibling tasks holding only the outer token wait while an inner
///   savepoint scope is open, because the innermost token is what the database advertises as
///   active.
///
/// `depth` counts enclosing scopes on the same database (outermost = 1). It names savepoints
/// (`loom_sp_<depth>`): sibling scopes serialize, so at most one scope per depth is open at a
/// time, and the recurring names keep the machinery statements cache-friendly instead of
/// minting an unbounded set of unique SQL strings.
final class TransactionToken: Sendable {
  let parent: TransactionToken?

  let depth: Int

  init(parent: TransactionToken?, depth: Int) {
    self.parent = parent
    self.depth = depth
  }

  /// Token of the innermost transaction scope enclosing the current task, if any.
  @TaskLocal static var current: TransactionToken?

  /// Whether `token` appears in the current task's chain of enclosing scopes.
  static func currentChainContains(_ token: TransactionToken) -> Bool {
    chain(startingAt: current, contains: token)
  }

  /// Whether `token` appears in the parent chain that starts at `start` (inclusive).
  static func chain(startingAt start: TransactionToken?, contains token: TransactionToken) -> Bool {
    var node = start
    while let unwrapped = node {
      if unwrapped === token { return true }
      node = unwrapped.parent
    }
    return false
  }
}
