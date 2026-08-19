extension SQLBuilder {
  // SQLite has no boolean storage class, so a bound Swift `Bool` reaches a JSON document
  // as INTEGER 1/0 — which the library's own JSONBindable readers then refuse to decode
  // as Bool. The JSON builders route value arguments through here so Bool lands as a real
  // JSON boolean; everything else binds as usual. (The cast also unwraps a `Bool?` with a
  // value; a nil optional falls through and binds NULL, i.e. JSON null.)
  mutating func appendJSONArgument(_ value: any Expression) {
    if let bool = value as? Bool {
      appendLiteral(bool ? "JSON('true')" : "JSON('false')")
    } else {
      value.append(to: &self)
    }
  }
}
