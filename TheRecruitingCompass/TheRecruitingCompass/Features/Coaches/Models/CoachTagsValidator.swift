import Foundation

/// Client-side caps for coach tags/source, mirroring the web Zod `coachSchema`
/// (tags ≤ 20 items / ≤ 40 chars each; source ≤ 80 chars).
enum CoachTagsValidator {
  static let maxTags = 20
  static let maxTagLength = 40
  static let maxSourceLength = 80

  /// Trim each tag, drop empties, whitespace-only, over-length, and duplicates,
  /// preserving order; cap at `maxTags`.
  static func sanitize(_ tags: [String]) -> [String] {
    var seen = Set<String>()
    var out: [String] = []
    for raw in tags {
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty, trimmed.count <= maxTagLength, !seen.contains(trimmed) else { continue }
      seen.insert(trimmed)
      out.append(trimmed)
      if out.count == maxTags { break }
    }
    return out
  }

  /// Trimmed source, or nil when empty, whitespace-only, or over `maxSourceLength`.
  static func sanitizeSource(_ source: String?) -> String? {
    guard let trimmed = source?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmed.isEmpty, trimmed.count <= maxSourceLength else { return nil }
    return trimmed
  }
}
