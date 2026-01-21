/// Symbolic breakpoint target for debugging warnings.
///
/// This function serves as a breakpoint target for catching warnings during debugging.
/// Set a symbolic breakpoint on `breakOnWarning` in your debugger to pause execution
/// whenever a warning is logged, allowing you to inspect the call stack and context.
///
/// The `@inline(never)` attribute ensures this function always appears in the call stack
/// and can be reliably used as a breakpoint target.
///
/// - Note: This function intentionally does nothing. Its sole purpose is to be a
///         stable symbol for debugger breakpoints.
@inline(never)
public func breakOnWarning() {}

/// Tracks whether the debugger breakpoint hint has been displayed to avoid repetition.
private nonisolated(unsafe) var breakOnWarningInfoShown: Bool = false

/// Logs a warning message and triggers a debugger breakpoint opportunity.
///
/// This function prints a warning message prefixed with `[LoomCore] WARNING:` to the console.
/// It also calls ``breakOnWarning()`` to allow developers to catch warnings during debugging
/// by setting a symbolic breakpoint.
///
/// The following example demonstrates its usage:
///
///     warn("Database schema version mismatch detected")
///     // Output: [LoomCore] WARNING: Database schema version mismatch detected
///     // Output: [LoomCore] Set a symbolic breakpoint on `breakOnWarning` to see warnings in the debugger
///
/// - Parameter message: The warning message to log.
func warn(_ message: String) {
  print("[LoomCore] WARNING: \(message)")
  if !breakOnWarningInfoShown {
    breakOnWarningInfoShown = true
    print("[LoomCore] Set a symbolic breakpoint on `breakOnWarning` to see warnings in the debugger")
  }
  breakOnWarning()
}
