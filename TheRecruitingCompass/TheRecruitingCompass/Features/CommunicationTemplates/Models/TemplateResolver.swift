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

  /// `column:<table>.<col>` (KNOWN_TABLES only) or `pref:player.<key>`; else nil.
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
