import SwiftUI
import XCTest
@testable import TheRecruitingCompass

/// Guards what the Help screens render, not just the copy constants: reverting the view must turn these red.
@MainActor
final class HelpSectionDetailViewTests: XCTestCase {
  nonisolated deinit {}

  private func renderedText(_ section: HelpSection) -> String {
    Self.strings(in: HelpSectionDetailView(section: section), depth: 0).joined(separator: "\n")
  }

  /// Walks the SwiftUI value tree (evaluating each composite view's `body`) and collects every string it holds.
  /// Reflection instead of a hosted accessibility tree, which SwiftUI does not populate without assistive tech.
  private static func strings(in node: Any, depth: Int) -> [String] {
    if let text = node as? String { return [text] }
    guard depth < 40 else { return [] }
    let mirror = Mirror(reflecting: node)
    guard let style = mirror.displayStyle, [.struct, .enum, .tuple, .optional, .collection].contains(style) else { return [] }
    var children = mirror.children.map(\.value)
    if let view = node as? any View, !(node is HelpFeedbackView), let body = evaluatedBody(of: view) {
      children.append(body)
    }
    return children.flatMap { strings(in: $0, depth: depth + 1) }
  }

  private static func evaluatedBody<V: View>(of view: V) -> Any? {
    V.Body.self == Never.self ? nil : view.body
  }

  func test_accountSectionRendersEveryAccountHasAFamily() {
    let text = renderedText(.account)
    for copy in [
      HelpFamilyCopy.sectionTitle, HelpFamilyCopy.everyAccountIntro, HelpFamilyCopy.createdForYou,
      HelpFamilyCopy.invitedJoin, HelpFamilyCopy.removedOrDeleted, HelpFamilyCopy.missingFamilyIntro,
      HelpFamilyCopy.stillLoading, HelpFamilyCopy.loadFailed, HelpFamilyCopy.noFamilyYet
    ] {
      XCTAssertTrue(text.contains(copy), "Account & Settings help is missing: \(copy)")
    }
  }

  func test_gettingStartedPointsToAccountSectionWithoutDuplicatingIt() {
    let text = renderedText(.gettingStarted)
    XCTAssertTrue(text.contains(HelpFamilyCopy.gettingStartedCallout), "callout missing")
    XCTAssertTrue(text.contains(HelpFamilyCopy.addingFamilyIntro), "intro missing")
    XCTAssertFalse(text.contains(HelpFamilyCopy.everyAccountIntro))
    XCTAssertFalse(text.contains(HelpFamilyCopy.noFamilyYet))
  }

  func test_gettingStartedInviteStepSaysWhoPicksARole() {
    let text = renderedText(.gettingStarted)
    XCTAssertTrue(text.contains(HelpFamilyCopy.inviteFamilyMemberStep), "invite step missing role rule")
    XCTAssertTrue(text.contains("chooses a role (Player or Parent)"))
    XCTAssertFalse(text.contains(Self.oldFamilyInviteStep), "old invite step without role rule still shown")
  }

  func test_accountInviteStepSaysWhoPicksARole() {
    let text = renderedText(.account)
    XCTAssertTrue(text.contains(HelpFamilyCopy.inviteMemberStep), "invite step missing role rule")
    XCTAssertTrue(text.contains("invites parents and relatives only"))
    XCTAssertFalse(text.contains(Self.oldAccountInviteStep), "old invite step without role rule still shown")
  }

  private static let oldFamilyInviteStep =
    "Enter their email address and tap Send invite. They'll receive an email to create their account "
    + "and join your family unit."
  private static let oldAccountInviteStep =
    "Enter their email and tap Send invite. They'll receive an invitation to create a linked account."

  func test_bulletRowRendersItsLine() {
    let text = Self.strings(in: HelpBulletRow(line: "probe").body, depth: 0)
    XCTAssertTrue(text.contains("probe"), "bullet row body must render its line, got \(text)")
  }
}
