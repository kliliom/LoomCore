// SQLite3 constants used throughout the library.

import SQLite3

// SQLITE_STATIC: data pointer remains valid for the statement's lifetime; SQLite will not copy or free it.
// Safe for string literals, compile-time constants, and any buffer guaranteed to outlive statement execution.
let sqliteStatic = unsafeBitCast(0, to: sqlite3_destructor_type.self)

// SQLITE_TRANSIENT: data pointer may become invalid after the binding call returns; SQLite copies immediately.
// Required for temporary buffers, local variables, or any data that may be mutated or deallocated before execution.
let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
