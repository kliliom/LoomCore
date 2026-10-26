import SQLite3

// SQLITE_STATIC, whose C macro Swift cannot import: SQLite neither copies nor frees the buffer,
// so it must stay valid until the statement is finalized or the parameter is rebound.
let sqliteStatic = unsafeBitCast(0, to: sqlite3_destructor_type.self)

// SQLITE_TRANSIENT, whose C macro Swift cannot import: SQLite copies the buffer before the bind call
// returns, so any temporary buffer is safe.
let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
