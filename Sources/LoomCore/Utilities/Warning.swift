import os

/// Symbolic breakpoint target for debugging warnings.
///
/// Set a symbolic breakpoint on `breakOnWarning` to pause whenever LoomCore logs a warning,
/// then inspect the call stack to see what triggered it. The `@inline(never)` attribute keeps
/// this function in the stack as a stable debugger symbol; the body is intentionally empty.
///
/// In LLDB:
///
/// ```
/// (lldb) breakpoint set --name breakOnWarning
/// ```
///
/// In Xcode, add a Symbolic Breakpoint with the symbol `breakOnWarning`.
@inline(never)
public func breakOnWarning() {}

private let breakOnWarningLock = OSAllocatedUnfairLock(initialState: false)

func warn(_ message: String) {
  print("[LoomCore] WARNING: \(message)")
  let shouldShow = breakOnWarningLock.withLock { shown in
    if !shown {
      shown = true
      return true
    }
    return false
  }
  if shouldShow {
    print("[LoomCore] Set a symbolic breakpoint on `breakOnWarning` to see warnings in the debugger")
  }
  breakOnWarning()
}
