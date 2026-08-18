import Foundation

/// Pure `{{key}}` template renderer, ported from web `utils/templateResolver.ts`.
/// Known keys are substituted; unknown keys are left intact so callers can gate on them.
enum TemplateResolver {
  private static let tokenPattern = #"\{\{(\w+)\}\}"#

  static func render(_ body: String, values: [String: String]) -> String {
    guard let regex = try? NSRegularExpression(pattern: tokenPattern) else { return body }
    var result = body
    let full = NSRange(body.startIndex..., in: body)
    // Replace right-to-left so each replacement never shifts an as-yet-unprocessed range.
    for match in regex.matches(in: body, range: full).reversed() {
      guard let matchRange = Range(match.range, in: result),
            let keyRange = Range(match.range(at: 1), in: result) else { continue }
      let key = String(result[keyRange])
      if let value = values[key] {
        result.replaceSubrange(matchRange, with: value)
      }
    }
    return result
  }

  /// Render, then gracefully handle OPTIONAL unresolved tokens: strip the token, and if its
  /// line collapses to just a label + separators, drop the whole line. REQUIRED unresolved
  /// tokens are left intact so they still show in preview and gate the send.
  /// Mirrors web `renderClean` — keep the two byte-identical.
  static func renderClean(_ body: String, values: [String: String], requiredKeys: Set<String>) -> String {
    let rendered = render(body, values: values)
    var kept: [String] = []
    for line in rendered.components(separatedBy: "\n") {
      let optional = findUnresolved(line).filter { !requiredKeys.contains($0) }
      guard !optional.isEmpty else { kept.append(line); continue }
      var cleaned = line
      for key in optional { cleaned = cleaned.replacingOccurrences(of: "{{\(key)}}", with: "") }
      if isLabelOnly(cleaned) { continue }
      kept.append(tidyLine(cleaned))
    }
    let joined = kept.joined(separator: "\n")
      .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
    return joined.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static let lineSeparators = CharacterSet(charactersIn: " \t—-|,·•")

  /// True when — after removing a leading "Label:" and all separators/space — nothing
  /// meaningful remains, and no other `{{token}}` sits on the line.
  private static func isLabelOnly(_ line: String) -> Bool {
    if line.contains("{{") { return false }
    var probe = line
    if let r = probe.range(of: #"^\s*[A-Za-z][A-Za-z ]*:"#, options: .regularExpression) {
      probe.removeSubrange(r)
    }
    return probe.unicodeScalars.allSatisfy { lineSeparators.contains($0) }
  }

  /// Collapse runs of spaces and strip dangling leading/trailing separators.
  private static func tidyLine(_ line: String) -> String {
    var s = line.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
    s = s.replacingOccurrences(of: #"^[ \t—\-|,·•]+"#, with: "", options: .regularExpression)
    s = s.replacingOccurrences(of: #"[ \t—\-|,·•]+$"#, with: "", options: .regularExpression)
    return s
  }

  static func findUnresolved(_ text: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: tokenPattern) else { return [] }
    var seen = Set<String>()
    var keys: [String] = []
    for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
      guard let keyRange = Range(match.range(at: 1), in: text) else { continue }
      let key = String(text[keyRange])
      if seen.insert(key).inserted { keys.append(key) }
    }
    return keys
  }

  // MARK: - Registry-driven resolution (Phase 2a)

  private static let knownTables: Set<String> = ["users", "schools", "coaches", "events"]

  /// COMPUTED formatter map, keyed by variable key (scalars + metrics).
  /// Event/derived values come through `ResolverContext.derived`, not this map (matches web).
  static let computed: [String: @Sendable (ResolverContext) -> String?] =
    TemplateComputed.scalars.merging(TemplateComputed.metrics) { a, _ in a }

  /// `column:<table>.<col>` (KNOWN_TABLES only), `pref:player.<key>`, or `pref:location.<key>`; else nil.
  static func resolveSourcePath(_ path: String?, _ ctx: ResolverContext) -> String? {
    guard let path else { return nil }
    if let body = path.stripping(prefix: "column:") {
      let parts = body.split(separator: ".", maxSplits: 1).map(String.init)
      guard parts.count == 2, knownTables.contains(parts[0]) else { return nil }
      return ctx.tables[parts[0]]?[parts[1]]
    }
    if let key = path.stripping(prefix: "pref:player.") {
      return ctx.prefs[key]
    }
    if let key = path.stripping(prefix: "pref:location.") {
      return ctx.locationPrefs[key]
    }
    return nil
  }

  /// Registry → resolved values map. Null/empty OMITTED (so `{{token}}` survives → gates send).
  static func buildValues(registry: [TemplateVariableDef], context ctx: ResolverContext) -> [String: String] {
    var values: [String: String] = [:]
    for def in registry {
      let resolved: String?
      switch def.sourceType {
      case .column:
        resolved = resolveSourcePath(def.sourcePath, ctx)
      case .authored:
        resolved = ctx.authored[def.key]
      case .computed, .system:
        resolved = computed[def.key]?(ctx) ?? ctx.derived[def.key]
      case .unknown:
        resolved = nil
      }
      if let resolved, !resolved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        values[def.key] = resolved
      }
    }
    return values
  }
}

private extension String {
  func stripping(prefix: String) -> String? {
    hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
  }
}
