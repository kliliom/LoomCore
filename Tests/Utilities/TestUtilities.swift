import Foundation

func tmpDatabaseURL() -> URL {
  let tempDir = FileManager.default.temporaryDirectory
  let dbPath = tempDir.appendingPathComponent("test-\(UUID().uuidString).db")
  return dbPath
}

extension URL {
  func remove() {
    try? FileManager.default.removeItem(at: self)
  }
}
