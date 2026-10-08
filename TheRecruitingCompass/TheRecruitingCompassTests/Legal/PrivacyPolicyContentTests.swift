import XCTest
@testable import TheRecruitingCompass

/// Drift guard: pins the text ported from the web `pages/legal/privacy.vue`. When the web policy changes,
/// port it into `PrivacyPolicyContent`, then update this fixture and `LegalRevision.lastUpdated` together.
final class PrivacyPolicyContentTests: XCTestCase {
  private let expectedHeadings = [
    "1. Introduction",
    "2. Information We Collect",
    "3. How We Use Your Information",
    "4. Third-Party Data Sources",
    "5. Sharing Your Information",
    "6. Data Security",
    "7. Data Retention",
    "8. Your Privacy Rights",
    "9. Cookies and Tracking Technologies",
    "10. Children's Privacy (COPPA)",
    "11. Third-Party Links",
    "12. Changes to This Privacy Policy",
    "13. Contact Us"
  ]

  private var allText: String {
    PrivacyPolicyContent.sections.flatMap { section in
      [section.heading] + section.blocks.flatMap(\.texts)
    }.joined(separator: "\n")
  }

  private func section(_ heading: String) throws -> PrivacyPolicyContent.Section {
    try XCTUnwrap(PrivacyPolicyContent.sections.first { $0.heading == heading })
  }

  private func text(of heading: String) throws -> String {
    try section(heading).blocks.flatMap(\.texts).joined(separator: "\n")
  }

  func testSectionHeadingsMatchWebPolicy() {
    XCTAssertEqual(PrivacyPolicyContent.sections.map(\.heading), expectedHeadings)
  }

  func testLastUpdatedIsOctober2_2026() {
    let parts = Calendar(identifier: .gregorian).dateComponents(
      [.year, .month, .day], from: LegalRevision.lastUpdated)
    XCTAssertEqual(parts.year, 2026)
    XCTAssertEqual(parts.month, 10)
    XCTAssertEqual(parts.day, 2)
  }

  func testTermsRevisionIsUnchanged() {
    let parts = Calendar(identifier: .gregorian).dateComponents(
      [.year, .month, .day], from: LegalRevision.termsLastUpdated)
    XCTAssertEqual([parts.year, parts.month, parts.day], [2026, 9, 3])
  }

  func testMarketingEmailsSubsectionDescribesAdultOptIn() throws {
    let uses = try section("3. How We Use Your Information")
    XCTAssertTrue(uses.blocks.contains(.subheading("Marketing Emails")))
    let body = try text(of: "3. How We Use Your Information")
    XCTAssertTrue(body.contains("Only adult account holders can opt in: parents, and players who are 18 or older."))
    XCTAssertTrue(body.contains("Settings → Notifications"))
    XCTAssertTrue(body.contains("Every marketing email includes an unsubscribe link."))
    XCTAssertTrue(body.contains("We do not use open or click tracking in our emails."))
    XCTAssertTrue(body.contains("The form is for parents and guardians of high school athletes."))
  }

  func testResendIsDisclosedInMarketingAndSharing() throws {
    XCTAssertTrue(try text(of: "3. How We Use Your Information").contains("We use Resend, an email service provider"))
    XCTAssertTrue(try text(of: "5. Sharing Your Information").contains("We use Resend to deliver email"))
  }

  func testThirdPartyAdvertisingSentenceIsScoped() throws {
    XCTAssertTrue(try text(of: "4. Third-Party Data Sources")
      .contains("with third parties for their own advertising or marketing purposes."))
  }

  func testChildrenSectionStatesNoMarketingToUnder18() throws {
    XCTAssertTrue(try text(of: "10. Children's Privacy (COPPA)")
      .contains("We do not send marketing email to users under 18."))
  }

  func testContactBlockHasMailingAddress() {
    XCTAssertEqual(PrivacyPolicyContent.contact.name, "The Recruiting Compass LLC")
    XCTAssertEqual(PrivacyPolicyContent.contact.address, "34125 Center Ridge Rd #1012\nNorth Ridgeville, OH 44039")
    XCTAssertEqual(PrivacyPolicyContent.contact.privacyEmail, "privacy@therecruitingcompass.com")
    XCTAssertEqual(PrivacyPolicyContent.contact.supportEmail, "support@therecruitingcompass.com")
  }

  func testRemovedLegacyMarketingWordingIsGone() {
    XCTAssertFalse(allText.contains("promotional information about paid features"))
  }
}
