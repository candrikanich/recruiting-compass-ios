import XCTest

/// Paywall rules a reviewer should not have to re-read for: no price in the app, no way out to web checkout, and no
/// pressure language (the audience includes minors).
final class PaywallSourceGuardTests: XCTestCase {
  private static let sourceRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("TheRecruitingCompass")

  private static var sources: [(name: String, code: String)] {
    let features = sourceRoot.appendingPathComponent("Features")
    let paywall = features.appendingPathComponent("Paywall")
    let plan = features.appendingPathComponent("Entitlement/Views/PlanView.swift")
    var urls = [plan]
    if let walker = FileManager.default.enumerator(at: paywall, includingPropertiesForKeys: nil) {
      urls += walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }
    return urls.compactMap { url in
      guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
      return (url.lastPathComponent, strippingComments(from: text))
    }
  }

  private static func strippingComments(from source: String) -> String {
    source
      .replacingOccurrences(of: "/\\*[\\s\\S]*?\\*/", with: "", options: .regularExpression)
      .replacingOccurrences(of: "(?<!:)//.*", with: "", options: .regularExpression)
  }

  func test_sourcesWereFound() {
    let names = Self.sources.map(\.name)
    XCTAssertTrue(names.contains("PaywallView.swift"), "\(names)")
    XCTAssertTrue(names.contains("PaywallViewModel.swift"), "\(names)")
    XCTAssertTrue(names.contains("PlanView.swift"), "\(names)")
  }

  /// Currency symbol then digits, or a decimal amount. A lone `$0` / `$1` closure argument is not a price.
  private let priceLiteral = "\\$\\s?\\d{2,}|\\$\\s?\\d[.,]\\d|[€£]\\s?\\d|\\d+[.,]\\d{2}\\b"

  func test_noHardCodedPrice() {
    for source in Self.sources {
      XCTAssertNil(
        source.code.range(of: priceLiteral, options: .regularExpression),
        "\(source.name) contains a price literal; prices come from the store"
      )
    }
  }

  func test_noWebCheckoutLinkOrMention() {
    let banned = ["http://", "https://", "checkout", "stripe", "trc.app", "recruitingcompass.com", "openURL"]
    for source in Self.sources {
      for word in banned {
        XCTAssertNil(source.code.range(of: word, options: .caseInsensitive), "\(source.name) mentions \(word)")
      }
    }
  }

  func test_noPressureLanguage() {
    let banned = [
      "hurry", "limited time", "last chance", "don't miss", "act now", "expires", "only today", "running out",
      "before it's too late", "you'll lose", "don't wait", "special offer", "% off"
    ]
    for source in Self.sources {
      for phrase in banned {
        XCTAssertNil(source.code.range(of: phrase, options: .caseInsensitive), "\(source.name) says \(phrase)")
      }
    }
  }
}
