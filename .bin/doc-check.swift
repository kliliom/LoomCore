// Documentation drift checker. Invoked by .bin/doc-check — not meant to be run directly.
//
// Three phases, all failures aggregated:
//   1. llms.txt path validation — every backtick-quoted Sources/… or Tests/… path must exist.
//   2. Tutorial @Code chains — rebuild each tutorial's virtual project step by step and
//      typecheck the full file set at every step.
//   3. Code fences — extract ```swift fences from /// doc comments and markdown files,
//      wrap each in a generated harness, and typecheck it against the built module.
//
// Exit codes: 0 = clean, 1 = doc failures, 2 = infrastructure failure.

import Dispatch
import Foundation

// MARK: - Configuration

struct Config {
  var modules = ""
  var target = ""
  var scratch = ""
}

func parseArgs() -> Config {
  var config = Config()
  var args = CommandLine.arguments.dropFirst().makeIterator()
  while let arg = args.next() {
    switch arg {
    case "--modules": config.modules = args.next() ?? ""
    case "--target": config.target = args.next() ?? ""
    case "--scratch": config.scratch = args.next() ?? ""
    default: fatalInfra("unknown argument: \(arg)")
    }
  }
  if config.modules.isEmpty || config.target.isEmpty || config.scratch.isEmpty {
    fatalInfra("required: --modules <dir> --target <triple> --scratch <dir>")
  }
  return config
}

func fatalInfra(_ message: String) -> Never {
  print("doc-check: fatal: \(message)")
  exit(2)
}

let fm = FileManager.default

func exists(_ path: String) -> Bool { fm.fileExists(atPath: path) }

func readLines(_ path: String) -> [String] {
  guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
    fatalInfra("cannot read \(path)")
  }
  return content.components(separatedBy: "\n")
}

// MARK: - Failure collection

final class Failures {
  private let lock = NSLock()
  private(set) var messages: [String] = []
  func add(_ message: String) {
    lock.lock()
    messages.append(message)
    lock.unlock()
  }
}

let failures = Failures()

// MARK: - swiftc invocation

struct Typecheck {
  let config: Config

  /// Runs `xcrun swiftc -typecheck` over `files`, writing combined output to `logName`.
  /// Returns (success, logPath).
  func run(files: [String], logName: String, suppressWarnings: Bool) -> (ok: Bool, log: String) {
    let logPath = "\(config.scratch)/logs/\(logName).log"
    var arguments = [
      "swiftc", "-typecheck", "-parse-as-library", "-swift-version", "6",
      "-target", config.target,
      "-I", config.modules,
      "-module-cache-path", "\(config.scratch)/module-cache",
    ]
    if suppressWarnings { arguments.append("-suppress-warnings") }
    arguments.append(contentsOf: files)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    do {
      try process.run()
    } catch {
      fatalInfra("cannot launch swiftc: \(error)")
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let output = String(data: data, encoding: .utf8) ?? ""
    try? output.write(toFile: logPath, atomically: true, encoding: .utf8)
    return (process.terminationStatus == 0, logPath)
  }
}

// MARK: - Phase 1: llms.txt paths

func checkLLMSPaths() -> Int {
  let file = "llms.txt"
  guard exists(file) else {
    failures.add("\(file):1: file is missing")
    return 0
  }
  let regex = try! NSRegularExpression(pattern: "`((?:Sources|Tests)/[^`]+\\.swift)`")
  var count = 0
  for (index, line) in readLines(file).enumerated() {
    let range = NSRange(line.startIndex..., in: line)
    for match in regex.matches(in: line, range: range) {
      guard let pathRange = Range(match.range(at: 1), in: line) else { continue }
      let path = String(line[pathRange])
      count += 1
      if !exists(path) {
        failures.add("\(file):\(index + 1): referenced file does not exist: \(path)")
      }
    }
  }
  if count == 0 {
    failures.add("\(file):1: sanity floor: no Sources/ or Tests/ paths extracted — checker regex rot?")
  }
  return count
}

// MARK: - Phase 2: tutorial @Code chains

func checkTutorials(typecheck: Typecheck) -> Int {
  let tutorialsDir = "Sources/LoomCore/Documentation.docc/Tutorials"
  let resourcesDir = "\(tutorialsDir)/Resources"
  guard let entries = try? fm.contentsOfDirectory(atPath: tutorialsDir) else {
    fatalInfra("cannot list \(tutorialsDir)")
  }
  let tutorials = entries.filter { $0.hasSuffix(".tutorial") }.sorted()
  let directiveRegex = try! NSRegularExpression(
    pattern: "@Code\\(\\s*name:\\s*\"([^\"]+)\"\\s*,\\s*file:\\s*([A-Za-z0-9._-]+)"
      + "(?:\\s*,\\s*previousFile:\\s*([A-Za-z0-9._-]+))?\\s*\\)")

  var totalSteps = 0
  var referencedResources = Set<String>()

  for tutorial in tutorials {
    let tutorialPath = "\(tutorialsDir)/\(tutorial)"
    let tutorialName = (tutorial as NSString).deletingPathExtension
    // Insertion-ordered display-name → latest resource file map (snapshot semantics).
    var project: [(display: String, resource: String)] = []
    var seenInTutorial = Set<String>()
    var stepNumber = 0

    for (index, line) in readLines(tutorialPath).enumerated() {
      guard line.contains("@Code(") else { continue }
      let range = NSRange(line.startIndex..., in: line)
      guard let match = directiveRegex.firstMatch(in: line, range: range) else {
        failures.add("\(tutorialPath):\(index + 1): unparseable @Code directive")
        continue
      }
      func group(_ n: Int) -> String? {
        guard let r = Range(match.range(at: n), in: line) else { return nil }
        return String(line[r])
      }
      let display = group(1)!
      let resource = group(2)!
      let previous = group(3)
      stepNumber += 1
      totalSteps += 1
      referencedResources.insert(resource)

      if !exists("\(resourcesDir)/\(resource)") {
        failures.add("\(tutorialPath):\(index + 1): resource file does not exist: \(resource)")
        continue
      }
      // previousFile is a diff base and may cross display names; it must at least be a
      // resource this tutorial has already shown.
      if let previous, !seenInTutorial.contains(previous) {
        failures.add(
          "\(tutorialPath):\(index + 1): previousFile: \(previous) was never referenced"
            + " earlier in this tutorial")
      }
      seenInTutorial.insert(resource)
      if let existing = project.firstIndex(where: { $0.display == display }) {
        project[existing].resource = resource
      } else {
        project.append((display, resource))
      }

      let files = project.filter { !$0.display.hasSuffix("Package.swift") }
        .map { "\(resourcesDir)/\($0.resource)" }
      guard !files.isEmpty else { continue }
      let logName = String(format: "tutorial-%@-%02d", tutorialName, stepNumber)
      let result = typecheck.run(files: files, logName: logName, suppressWarnings: false)
      if !result.ok {
        failures.add(
          "\(tutorialPath):\(index + 1): tutorial step failed to typecheck (\(resource));"
            + " log: \(result.log)")
      }
    }
  }

  // Orphaned resources are exactly where drift hides.
  if let resources = try? fm.contentsOfDirectory(atPath: resourcesDir) {
    for resource in resources.sorted() where resource.hasSuffix(".swift") {
      if !referencedResources.contains(resource) {
        failures.add("\(resourcesDir)/\(resource):1: orphaned tutorial resource (no @Code references it)")
      }
    }
  }

  if totalSteps == 0 {
    failures.add("\(tutorialsDir):1: sanity floor: no @Code steps extracted — checker regex rot?")
  }
  return totalSteps
}

// MARK: - Phase 3: fence extraction

struct Fence {
  let file: String  // repo-relative path of the doc file
  let startLine: Int  // 1-based line of the first content line
  let lines: [(line: Int, text: String)]
}

/// Extracts ```swift fences from a stream of (lineNumber, text) pairs.
/// A fence is skipped when the preceding line is `<!-- doc-check: skip -->` (invisible in
/// rendered markdown) or its first line is `// doc-check: skip` (for doc comments).
func extractFences(file: String, stream: [(line: Int, text: String)]) -> [Fence] {
  var fences: [Fence] = []
  var open: (indent: Int, lines: [(line: Int, text: String)])? = nil
  var previousTrimmed = ""
  for (lineNumber, text) in stream {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    if var fence = open {
      if trimmed == "```" {
        fences.append(
          Fence(file: file, startLine: fence.lines.first?.line ?? lineNumber, lines: fence.lines))
        open = nil
      } else {
        let dropped = String(text.dropFirst(min(fence.indent, text.prefix(while: { $0 == " " }).count)))
        fence.lines.append((lineNumber, dropped))
        open = fence
      }
    } else if trimmed == "```swift" && previousTrimmed != "<!-- doc-check: skip -->" {
      let indent = text.prefix(while: { $0 == " " }).count
      open = (indent, [])
    }
    previousTrimmed = trimmed
  }
  return fences
}

/// Doc-comment stream: /// lines with the prefix stripped.
func docCommentStream(path: String) -> [(line: Int, text: String)] {
  var stream: [(Int, String)] = []
  for (index, line) in readLines(path).enumerated() {
    let trimmed = line.drop(while: { $0 == " " })
    guard trimmed.hasPrefix("///") else { continue }
    var content = trimmed.dropFirst(3)
    if content.hasPrefix(" ") { content = content.dropFirst() }
    stream.append((index + 1, String(content)))
  }
  return stream
}

func markdownStream(path: String) -> [(line: Int, text: String)] {
  readLines(path).enumerated().map { ($0.offset + 1, $0.element) }
}

// MARK: - Phase 3: harness generation

/// Tracks brace depth across lines, ignoring braces in string literals and comments.
struct DepthTracker {
  var depth = 0
  private var inMultilineString = false

  mutating func consume(_ line: String) {
    var chars = Array(line)
    var i = 0
    var inString = false
    if inMultilineString {
      // Look for closing """ on this line; everything before it is string content.
      if let close = line.range(of: "\"\"\"") {
        inMultilineString = false
        chars = Array(line[close.upperBound...])
        i = 0
      } else {
        return
      }
    }
    while i < chars.count {
      let c = chars[i]
      if inString {
        if c == "\\" { i += 2; continue }
        if c == "\"" { inString = false }
      } else {
        if c == "\"" {
          if i + 2 < chars.count, chars[i + 1] == "\"", chars[i + 2] == "\"" {
            inMultilineString = true
            // Rest of the line is string content unless it closes on the same line.
            let rest = String(chars[(i + 3)...])
            if let close = rest.range(of: "\"\"\"") {
              inMultilineString = false
              chars = Array(rest[close.upperBound...])
              i = 0
              continue
            }
            return
          }
          inString = true
        } else if c == "/" && i + 1 < chars.count && chars[i + 1] == "/" {
          return  // line comment
        } else if c == "{" {
          depth += 1
        } else if c == "}" {
          depth -= 1
        }
      }
      i += 1
    }
  }
}

let declarationKeywords: Set<String> = [
  "struct", "class", "enum", "actor", "protocol", "extension", "typealias", "func", "import",
]
let modifierKeywords: Set<String> = [
  "public", "private", "internal", "fileprivate", "final", "indirect", "static", "nonisolated",
]

/// Classifies a depth-0 line: is it the start of a top-level declaration?
/// Returns nil for attribute-only lines (classification deferred to the next line).
func classifiesAsDeclaration(_ line: String) -> Bool? {
  var tokens = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
  while let first = tokens.first {
    if first.hasPrefix("@") || modifierKeywords.contains(first) {
      tokens.removeFirst()
    } else {
      break
    }
  }
  guard let first = tokens.first else { return nil }  // attribute/modifier-only or blank line
  return declarationKeywords.contains(first)
}

struct Harness {
  let source: String
}

func buildHarness(fence: Fence, repoRoot: String) -> Harness? {
  // Skip marker: first non-empty line.
  if let firstContent = fence.lines.first(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }),
    firstContent.text.trimmingCharacters(in: .whitespaces) == "// doc-check: skip"
  {
    return nil
  }

  var imports: [String] = []
  var declLines: [(line: Int, text: String)] = []
  var stmtLines: [(line: Int, text: String)] = []

  var tracker = DepthTracker()
  var inDecl = false
  var pendingAttributes: [(line: Int, text: String)] = []

  for entry in fence.lines {
    let trimmed = entry.text.trimmingCharacters(in: .whitespaces)
    let depthBefore = tracker.depth
    tracker.consume(entry.text)

    if depthBefore > 0 {
      if inDecl { declLines.append(entry) } else { stmtLines.append(entry) }
      if tracker.depth == 0 { inDecl = false }
      continue
    }

    // depth 0 before this line
    if trimmed.hasPrefix("import ") {
      imports.append(trimmed)
      continue
    }
    if trimmed.isEmpty || trimmed.hasPrefix("//") {
      if pendingAttributes.isEmpty { stmtLines.append(entry) } else { pendingAttributes.append(entry) }
      continue
    }
    switch classifiesAsDeclaration(trimmed) {
    case nil:
      pendingAttributes.append(entry)
    case .some(true):
      declLines.append(contentsOf: pendingAttributes)
      pendingAttributes = []
      declLines.append(entry)
      if tracker.depth > 0 { inDecl = true }
    case .some(false):
      stmtLines.append(contentsOf: pendingAttributes)
      pendingAttributes = []
      stmtLines.append(entry)
    }
  }
  stmtLines.append(contentsOf: pendingAttributes)

  let fullText = fence.lines.map(\.text).joined(separator: "\n")
  let referencesDB = fullText.range(of: "\\bdb\\b", options: .regularExpression) != nil
  let declaresDB = fullText.range(of: "\\b(let|var)\\s+db\\b", options: .regularExpression) != nil
  let injectDB = referencesDB && !declaresDB

  let absolutePath = "\(repoRoot)/\(fence.file)"

  /// Emits bucket lines in contiguous #sourceLocation runs.
  func emit(_ bucket: [(line: Int, text: String)], into out: inout [String]) {
    var previousLine = Int.min
    for entry in bucket {
      if entry.line != previousLine + 1 {
        out.append("#sourceLocation(file: \"\(absolutePath)\", line: \(entry.line))")
      }
      out.append(entry.text)
      previousLine = entry.line
    }
    if !bucket.isEmpty { out.append("#sourceLocation()") }
  }

  var out: [String] = ["import Foundation", "import LoomCore"]
  for imp in Set(imports).sorted() where imp != "import Foundation" && imp != "import LoomCore" {
    out.append(imp)
  }
  out.append("")
  emit(declLines, into: &out)
  let hasStatements = stmtLines.contains { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
  if hasStatements || injectDB {
    out.append("")
    out.append("func __snippet() async throws {")
    if injectDB {
      out.append("  let db = try await Database.openInMemory()")
      out.append("  _ = db")
    }
    emit(stmtLines, into: &out)
    out.append("}")
  }
  return Harness(source: out.joined(separator: "\n") + "\n")
}

// MARK: - Phase 3 driver

func checkFences(typecheck: Typecheck, config: Config, repoRoot: String) -> Int {
  var fences: [Fence] = []

  // Doc comments in library sources (tutorial resources are covered by phase 2).
  let sourcesRoot = "Sources/LoomCore"
  if let enumerator = fm.enumerator(atPath: sourcesRoot) {
    for case let entry as String in enumerator {
      guard entry.hasSuffix(".swift"), !entry.contains("Documentation.docc/") else { continue }
      let path = "\(sourcesRoot)/\(entry)"
      fences.append(contentsOf: extractFences(file: path, stream: docCommentStream(path: path)))
    }
  }

  // Markdown files.
  var markdownFiles = ["README.md", "llms.txt", "Sources/LoomCore/Documentation.docc/LoomCore.md"]
  let articlesDir = "Sources/LoomCore/Documentation.docc/Articles"
  if let articles = try? fm.contentsOfDirectory(atPath: articlesDir) {
    markdownFiles.append(contentsOf: articles.sorted().filter { $0.hasSuffix(".md") }.map { "\(articlesDir)/\($0)" })
  }
  for path in markdownFiles where exists(path) {
    fences.append(contentsOf: extractFences(file: path, stream: markdownStream(path: path)))
  }

  if fences.isEmpty {
    failures.add("Sources/LoomCore:1: sanity floor: no ```swift fences extracted — checker rot?")
    return 0
  }

  // Generate harnesses.
  var jobs: [(index: Int, fence: Fence, harnessPath: String)] = []
  for (index, fence) in fences.enumerated() {
    guard let harness = buildHarness(fence: fence, repoRoot: repoRoot) else { continue }
    let harnessPath = String(format: "%@/harness/snippet-%03d.swift", config.scratch, index)
    do {
      try harness.source.write(toFile: harnessPath, atomically: true, encoding: .utf8)
    } catch {
      fatalInfra("cannot write \(harnessPath): \(error)")
    }
    jobs.append((index, fence, harnessPath))
  }

  // Typecheck each harness in parallel.
  DispatchQueue.concurrentPerform(iterations: jobs.count) { jobIndex in
    let job = jobs[jobIndex]
    let logName = String(format: "snippet-%03d", job.index)
    let result = typecheck.run(files: [job.harnessPath], logName: logName, suppressWarnings: true)
    if !result.ok {
      let log = (try? String(contentsOfFile: result.log, encoding: .utf8)) ?? ""
      let errorLines = log.components(separatedBy: "\n")
        .filter { $0.contains("error:") }
        .prefix(4)
      var message = "\(job.fence.file):\(job.fence.startLine): snippet failed to typecheck; log: \(result.log)"
      for errorLine in errorLines {
        message += "\n  " + errorLine.replacingOccurrences(of: repoRoot + "/", with: "")
      }
      failures.add(message)
    }
  }
  return jobs.count
}

// MARK: - Main

let config = parseArgs()
let repoRoot = fm.currentDirectoryPath

for sub in ["logs", "harness", "module-cache"] {
  try? fm.createDirectory(atPath: "\(config.scratch)/\(sub)", withIntermediateDirectories: true)
}
guard exists("\(config.modules)/LoomCore.swiftmodule") else {
  fatalInfra("LoomCore.swiftmodule not found in \(config.modules) — run swift build first")
}

let typecheck = Typecheck(config: config)

let pathCount = checkLLMSPaths()
let stepCount = checkTutorials(typecheck: typecheck)
let fenceCount = checkFences(typecheck: typecheck, config: config, repoRoot: repoRoot)

let sorted = failures.messages.sorted()
for message in sorted {
  print(message)
}
if sorted.isEmpty {
  print("doc-check: OK (\(stepCount) tutorial steps, \(fenceCount) snippets, \(pathCount) llms.txt paths)")
  exit(0)
} else {
  print("doc-check: \(sorted.count) failure(s)")
  exit(1)
}
