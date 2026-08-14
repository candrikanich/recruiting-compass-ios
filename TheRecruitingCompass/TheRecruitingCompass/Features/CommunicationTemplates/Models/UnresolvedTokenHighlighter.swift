import SwiftUI

/// Pure: renders text with `{{token}}` runs styled amber/bold so the preview shows what's
/// still missing. Fails open — on a regex miss it returns the plain text unstyled.
enum UnresolvedTokenHighlighter {
  private static let pattern = #"\{\{\w+\}\}"#

  static func attributed(_ text: String, tokenColor: Color) -> AttributedString {
    var result = AttributedString(text)
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
    let ns = text as NSString
    for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
      guard let swiftRange = Range(match.range, in: text),
            let lo = AttributedString.Index(swiftRange.lowerBound, within: result),
            let hi = AttributedString.Index(swiftRange.upperBound, within: result) else { continue }
      result[lo..<hi].foregroundColor = tokenColor
      result[lo..<hi].font = .body.bold()
    }
    return result
  }
}
