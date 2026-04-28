/// SQLite3 constants used throughout the library.
///
/// This file defines commonly used SQLite3 destructor types that control
/// memory management behavior when binding values to prepared statements.

import SQLite3

/// SQLite static destructor type (SQLITE_STATIC).
///
/// Indicates that the data pointer passed to SQLite is constant and will remain valid
/// for the lifetime of the statement or until the value is changed. SQLite will not
/// attempt to free or copy the memory.
///
/// Use this when:
/// - The data is a string literal or compile-time constant
/// - The data is guaranteed to outlive the statement execution
/// - You want to avoid unnecessary memory copies for performance
let sqliteStatic = unsafeBitCast(0, to: sqlite3_destructor_type.self)

/// SQLite transient destructor type (SQLITE_TRANSIENT).
///
/// Indicates that the data pointer passed to SQLite is temporary and may become invalid
/// after the binding call returns. SQLite will make a private copy of the data immediately.
///
/// Use this when:
/// - The data may be deallocated or modified before statement execution
/// - The data comes from temporary buffers or local variables
/// - You need SQLite to manage its own copy of the data
let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
