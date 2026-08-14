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
}
