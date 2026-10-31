import Foundation

/// The backend rejects non-http(s) `video_links.url` (web#1494), and user-supplied URLs must never be opened with
/// another scheme (`javascript:`, `file:`, `tel:` ...). Parity with web's http(s)-only check.
enum HTTPURL {
  /// True only when `string` begins with `http://` or `https://` (case-insensitive, no leading whitespace)
  /// and parses as a URL.
  static func isValid(_ string: String) -> Bool {
    url(from: string) != nil
  }

  /// The parsed URL when `string` is a valid http(s) URL, otherwise nil.
  static func url(from string: String) -> URL? {
    let lowered = string.lowercased()
    guard lowered.hasPrefix("http://") || lowered.hasPrefix("https://") else { return nil }
    return URL(string: string)
  }
}
