import Testing
@testable import LoomCore

@Test func example() async throws {
  let db = try await Database.openInMemory()

  try await db.exec(
    raw: "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)"
  )

  for i in 1...5 {
    try await db.exec("INSERT INTO users (name, age) VALUES (\("User \(i)"), \(20 + i))")
  }
}
