import Foundation

/// The backend rejects non-http(s) `video_links.url` (web#1494), and user-supplied URLs must never be opened with
/// another scheme (`javascript:`, `file:`, `tel:` ...). Parity with web's http(s)-only check.
enum HTTPURL {
  static let invalidMessage = String(localized: "URL must start with http:// or https://")

  private static let schemes = ["http://", "https://"]

  /// `string` without trailing whitespace (a pasted link often carries a newline or space), or nil unless it begins
  /// with `http://` or `https://` (case-insensitive, no leading whitespace) and parses to a URL with a host.
  static func cleaned(_ string: String) -> String? {
    let trimmed = String(string.reversed().drop(while: \.isWhitespace).reversed())
    guard schemes.contains { trimmed.lowercased().hasPrefix($0) },
          let host = URL(string: trimmed)?.host(), !host.isEmpty else { return nil }
    return trimmed
  }

  static func isValid(_ string: String) -> Bool {
    cleaned(string) != nil
  }

  static func url(from string: String) -> URL? {
    cleaned(string).flatMap { URL(string: $0) }
  }

  /// True when `string` is a prefix of a scheme or already starts with one, so more typing can still make it valid.
  static func canBecomeValid(_ string: String) -> Bool {
    let lowered = string.lowercased()
    return schemes.contains { $0.hasPrefix(lowered) || lowered.hasPrefix($0) }
  }
}
