import SwiftUI
import XCTest
@testable import TheRecruitingCompass

/// Guards what the Help screens render, not just the copy constants: reverting the view must turn these red.
@MainActor
final class HelpSectionDetailViewTests: XCTestCase {
  nonisolated deinit {}

  private func renderedText(_ section: HelpSection) -> String {
    Self.values(of: String.self, in: HelpSectionDetailView(section: section)).joined(separator: "\n")
  }

  /// Walks the SwiftUI value tree (evaluating each composite view's `body`) and collects every `T` it holds.
  /// Reflection instead of a hosted accessibility tree, which SwiftUI does not populate without assistive tech.
  private static func values<T>(of kind: T.Type, in node: Any, depth: Int = 0) -> [T] {
    if let match = node as? T { return [match] }
    guard depth < 40 else { return [] }
    let mirror = Mirror(reflecting: node)
    let walkable: [Mirror.DisplayStyle] = [.struct, .enum, .tuple, .optional, .collection]
    guard let style = mirror.displayStyle, walkable.contains(style) else { return [] }
    var children = mirror.children.map(\.value)
    // SwiftUI containers (VStack...) already expose their content as stored properties; evaluating their `body`
    // as well would visit every child twice, which would hide a duplicated card from an exactly-one check.
    let isFrameworkView = String(reflecting: type(of: node)).hasPrefix("SwiftUI.")
    if let view = node as? any View, !isFrameworkView, !(node is HelpFeedbackView), let body = evaluatedBody(of: view) {
      children.append(body)
    }
    return children.flatMap { values(of: kind, in: $0, depth: depth + 1) }
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

  /// Literal copy of the role rule in web `pages/help/family.vue` / `account.vue` (web#1447). Deliberately not the
  /// `HelpFamilyCopy` constant, so wording drift in the app copy turns these red.
  private static let webRoleRule =
    "Only a parent whose family has no player yet chooses a role (Player or Parent) first. "
    + "A player, or a parent whose family already has a player, invites parents and relatives only"

  private func inviteStepBody(_ section: HelpSection, title: String) throws -> String {
    let cards = Self.values(of: HelpStepCard.self, in: HelpSectionDetailView(section: section))
    let matches = cards.filter { $0.step == 2 && $0.title == title }
    XCTAssertEqual(matches.count, 1, "expected exactly one step 2 card titled \(title)")
    return try XCTUnwrap(matches.first).bodyText
  }

  func test_gettingStartedInviteStepSaysWhoPicksARole() throws {
    let body = try inviteStepBody(.gettingStarted, title: "Invite a family member")
    XCTAssertTrue(body.contains(Self.webRoleRule + ", so there is no role to pick."), "got: \(body)")
    XCTAssertEqual(body, HelpFamilyCopy.inviteFamilyMemberStep)
    XCTAssertFalse(body.contains(Self.oldFamilyInviteStep), "old invite step without role rule still shown")
  }

  func test_accountInviteStepSaysWhoPicksARole() throws {
    let body = try inviteStepBody(.account, title: "Invite a member")
    XCTAssertTrue(body.contains(Self.webRoleRule), "got: \(body)")
    XCTAssertEqual(body, HelpFamilyCopy.inviteMemberStep)
    XCTAssertFalse(body.contains(Self.oldAccountInviteStep), "old invite step without role rule still shown")
  }

  private static let oldFamilyInviteStep =
    "Enter their email address and tap Send invite. They'll receive an email to create their account "
    + "and join your family unit."
  private static let oldAccountInviteStep =
    "Enter their email and tap Send invite. They'll receive an invitation to create a linked account."

  func test_bulletRowRendersItsLine() {
    let text = Self.values(of: String.self, in: HelpBulletRow(line: "probe").body)
    XCTAssertTrue(text.contains("probe"), "bullet row body must render its line, got \(text)")
  }
}
