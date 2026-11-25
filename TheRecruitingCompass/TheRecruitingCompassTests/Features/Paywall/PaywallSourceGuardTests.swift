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

  private static func source(_ relativePath: String) -> String {
    let url = sourceRoot.appendingPathComponent("Features").appendingPathComponent(relativePath)
    return (try? String(contentsOf: url, encoding: .utf8)).map(strippingComments(from:)) ?? ""
  }

  /// Comment-free source with every whitespace character removed, so a reformat cannot hide or fake a match.
  private static func compactSource(atRoot fileName: String) -> String {
    let url = sourceRoot.appendingPathComponent(fileName)
    let code = (try? String(contentsOf: url, encoding: .utf8)).map(strippingComments(from:)) ?? ""
    return code.filter { !$0.isWhitespace }
  }

  /// The write-gate alert must read the role-aware text, not the parent-only constant.
  func test_writeGateNoticeIsRoleAware() {
    let modifier = Self.source("Entitlement/Views/WriteGatedModifier.swift")
    XCTAssertTrue(modifier.contains("gate.noticeMessage"), "the notice must come from the gate's role-aware text")
    XCTAssertFalse(modifier.contains("WriteGate.subscriptionMessage"), "the parent-only text must not be hard-wired")
  }

  /// The write gate must be told the signed-in user's role; a fixed role would tell every athlete to renew.
  func test_writeGateGetsTheSignedInRole() {
    let modifier = Self.source("Entitlement/Views/WriteGatedModifier.swift").filter { !$0.isWhitespace }
    guard let attach = modifier.range(of: "gate.attach("),
      let arguments = Self.firstBracedBlock(in: modifier[attach.lowerBound...], open: "(", close: ")")
    else { return XCTFail("the write gate is never attached") }
    let readsSignedInRole = "role:\\{(\\[authManager\\]in)?authManager\\.user\\?\\.role\\}$"
    XCTAssertNotNil(
      arguments.range(of: readsSignedInRole, options: .regularExpression),
      "the write gate must read the signed-in role, got \(arguments)"
    )
  }

  /// Only a parent may become a RevenueCat customer, so the app must hand billing the signed-in role and re-sync
  /// when that role loads, not just when the user id changes.
  func test_appBillingSessionReadsTheSignedInRoleAndResyncsOnIt() {
    let app = Self.compactSource(atRoot: "TheRecruitingCompassApp.swift")
    if let start = app.range(of: "BillingSession("),
      let arguments = Self.firstBracedBlock(in: app[start.lowerBound...], open: "(", close: ")") {
      XCTAssertTrue(
        arguments.hasSuffix("role:{AuthManager.shared.user?.role}"),
        "billing must read the signed-in role, got \(arguments)"
      )
    } else {
      XCTFail("the app never creates a BillingSession")
    }

    guard let sync = app.range(of: "billingSession.sync("),
      let task = app[..<sync.lowerBound].range(of: ".task(id:", options: .backwards),
      let key = Self.firstBracedBlock(in: app[task.lowerBound...], open: "(", close: ")")
    else { return XCTFail("billing is not synced from a .task(id:)") }
    XCTAssertTrue(key.contains("userId:authManager.user?.id"), "billing must re-sync when the account changes")
    XCTAssertTrue(key.contains("role:authManager.user?.role"), "billing must re-sync when the role loads, got \(key)")
  }

  /// Starting the SDK contacts RevenueCat. Only the adapter may do it, once, already identified as the user, so no
  /// anonymous customer exists; a second call site (say, back in `App.init`) would send every install's IP.
  func test_onlyTheAdapterStartsTheSDK_andOnlyAsAnIdentifiedUser() {
    var callers: [String] = []
    if let walker = FileManager.default.enumerator(at: Self.sourceRoot, includingPropertiesForKeys: nil) {
      for case let url as URL in walker where url.pathExtension == "swift" {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
        let code = Self.strippingComments(from: text).filter { !$0.isWhitespace }
        if code.contains("Purchases.configure(") || code.contains("Configuration.Builder(") {
          callers.append(url.lastPathComponent)
        }
      }
    }
    XCTAssertEqual(callers, ["RevenueCatPurchases.swift"], "only the adapter may start the SDK")

    let adapter = Self.source("Paywall/Services/RevenueCatPurchases.swift").filter { !$0.isWhitespace }
    XCTAssertEqual(adapter.components(separatedBy: "Purchases.configure(").count - 1, 1)
    XCTAssertTrue(
      adapter.contains("Purchases.configure(withAPIKey:apiKey,appUserID:appUserId)"),
      "the SDK must start identified as the signed-in user, never anonymous"
    )
  }

  /// The kill switch must be read, after the cold-launch flag refresh, before the SDK can start.
  func test_appBillingSessionWaitsForAndReadsThePaywallKillSwitch() {
    let app = Self.compactSource(atRoot: "TheRecruitingCompassApp.swift")
    guard let start = app.range(of: "BillingSession("),
      let arguments = Self.firstBracedBlock(in: app[start.lowerBound...], open: "(", close: ")")
    else { return XCTFail("the app never creates a BillingSession") }
    XCTAssertTrue(arguments.contains("isPaywallEnabled:{"), "billing must be told the kill switch, got \(arguments)")
    XCTAssertTrue(arguments.contains("awaitflags.waitForInitialState()"), "the kill switch must be resolved first")
    XCTAssertTrue(arguments.contains("returnflags.isEnabled(.paywall)"), "billing must read the paywall switch")
    XCTAssertTrue(app.contains("_featureFlagStore=State(initialValue:flags)"), "billing must read the app's own store")
  }

  /// The text between the first `open` and its matching `close` in `text`, or nil when they do not balance.
  private static func firstBracedBlock(
    in text: Substring, open: Character = "{", close: Character = "}"
  ) -> Substring? {
    guard let start = text.firstIndex(of: open) else { return nil }
    var depth = 0
    var index = start
    while index < text.endIndex {
      if text[index] == open { depth += 1 }
      if text[index] == close { depth -= 1 }
      if depth == 0 { return text[text.index(after: start)..<index] }
      index = text.index(after: index)
    }
    return nil
  }

  /// A frame or content shape outside a borderless `Button` can grow its layout box without growing the tap area,
  /// so Terms, Privacy and Restore keep both inside the label closure.
  func test_legalAndRestoreTapAreasLiveInsideTheButtonLabel() {
    let view = Self.source("Paywall/Views/PaywallView.swift")
    for marker in ["func legalButton", "Task { await model.restore() }"] {
      guard let start = view.range(of: marker)?.lowerBound,
        let label = view[start...].range(of: "label:"),
        let labelBody = Self.firstBracedBlock(in: view[label.upperBound...])
      else {
        XCTFail("\(marker) is not a label-style Button")
        continue
      }
      XCTAssertTrue(labelBody.contains(".frame(minHeight: 44)"), "\(marker): 44pt frame outside the label")
      XCTAssertTrue(labelBody.contains(".contentShape(Rectangle())"), "\(marker): contentShape outside the label")
    }
  }
}
