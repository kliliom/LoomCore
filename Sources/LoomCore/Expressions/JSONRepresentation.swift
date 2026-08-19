// The JSON/JSONB pairing, in one place: every dual-spelling function derives its SQL name
// here, so a misspelled prefix cannot compile and the text/binary rule is not re-derived
// per file.
enum JSONRepresentation: String, Sendable {
  /// Text-level `JSON_*` functions, returning TEXT.
  case text = "JSON"

  /// Binary `JSONB_*` functions (SQLite 3.45+), returning BLOB.
  case binary = "JSONB"

  /// `JSON_<function>` / `JSONB_<function>`; the bare `JSON()`/`JSONB()` conversions use
  /// `rawValue` directly.
  func sqlName(_ function: String) -> String {
    "\(rawValue)_\(function)"
  }
}
