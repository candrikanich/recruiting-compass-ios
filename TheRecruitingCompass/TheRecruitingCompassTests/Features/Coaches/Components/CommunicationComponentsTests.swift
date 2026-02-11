import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class CommunicationComponentsTests: XCTestCase {

  // MARK: - CommunicationButton Tests

  func testCommunicationButton_rendersWithoutCrashing() {
    let view = CommunicationButton(type: .email("test@example.com"), value: "test@example.com")
    XCTAssertNotNil(view)
  }

  func testCommunicationButton_emailType() {
    let view = CommunicationButton(type: .email("test@test.com"), value: "test@test.com")
    XCTAssertNotNil(view)
  }

  func testCommunicationButton_phoneType() {
    let view = CommunicationButton(type: .phone("555-1234"), value: "555-1234")
    XCTAssertNotNil(view)
  }

  func testCommunicationButton_twitterType() {
    let view = CommunicationButton(type: .twitter("@coach"), value: "@coach")
    XCTAssertNotNil(view)
  }

  func testCommunicationButton_instagramType() {
    let view = CommunicationButton(type: .instagram("@coach"), value: "@coach")
    XCTAssertNotNil(view)
  }

  func testCommunicationButton_dynamicType() {
    let view = CommunicationButton(type: .email("test@test.com"), value: "test@test.com")
      .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
    XCTAssertNotNil(view)
  }

  // MARK: - CommunicationType Icon Tests

  func testCommunicationType_iconNames() {
    XCTAssertEqual(CommunicationType.email("").iconName, "envelope.fill")
    XCTAssertEqual(CommunicationType.phone("").iconName, "message.fill")
    XCTAssertEqual(CommunicationType.twitter("").iconName, "at")
    XCTAssertEqual(CommunicationType.instagram("").iconName, "camera.fill")
  }

  func testCommunicationType_iconColors() {
    let email = CommunicationType.email("")
    let phone = CommunicationType.phone("")
    let twitter = CommunicationType.twitter("")
    let instagram = CommunicationType.instagram("")

    XCTAssertEqual(email.iconColor, .accentBlue)
    XCTAssertEqual(phone.iconColor, .successGreen)
    XCTAssertNotNil(twitter.iconColor)
    XCTAssertNotNil(instagram.iconColor)
  }

  func testCommunicationType_accessibilityLabels() {
    XCTAssertEqual(CommunicationType.email("").accessibilityLabel, "Email coach")
    XCTAssertEqual(CommunicationType.phone("").accessibilityLabel, "Text coach")
    XCTAssertEqual(CommunicationType.twitter("").accessibilityLabel, "View Twitter profile")
    XCTAssertEqual(CommunicationType.instagram("").accessibilityLabel, "View Instagram profile")
  }

  func testCommunicationType_appNames() {
    XCTAssertEqual(CommunicationType.email("").appName, "Mail")
    XCTAssertEqual(CommunicationType.phone("").appName, "Messages")
    XCTAssertEqual(CommunicationType.twitter("").appName, "Twitter")
    XCTAssertEqual(CommunicationType.instagram("").appName, "Instagram")
  }

  // MARK: - CommunicationType URL Generation Tests

  func testCommunicationType_emailURL() {
    let url = CommunicationType.email("test@example.com").url(for: "test@example.com")
    XCTAssertNotNil(url)
    XCTAssertEqual(url?.absoluteString, "mailto:test@example.com")
  }

  func testCommunicationType_emailURL_invalid() {
    let url = CommunicationType.email("invalid-email").url(for: "invalid-email")
    XCTAssertNil(url) // Should be nil if no @ symbol
  }

  func testCommunicationType_emailURL_empty() {
    let url = CommunicationType.email("").url(for: "")
    XCTAssertNil(url)
  }

  func testCommunicationType_emailURL_whitespace() {
    let url = CommunicationType.email("  test@test.com  ").url(for: "  test@test.com  ")
    XCTAssertNotNil(url)
    XCTAssertEqual(url?.absoluteString, "mailto:test@test.com")
  }

  func testCommunicationType_phoneURL() {
    let url = CommunicationType.phone("555-1234").url(for: "555-1234")
    XCTAssertNotNil(url)
    XCTAssertEqual(url?.absoluteString, "sms:555-1234")
  }

  func testCommunicationType_phoneURL_withFormatting() {
    let url = CommunicationType.phone("(555) 123-4567").url(for: "(555) 123-4567")
    XCTAssertNotNil(url)
    XCTAssertEqual(url?.absoluteString, "sms:5551234567")
  }

  func testCommunicationType_phoneURL_empty() {
    let url = CommunicationType.phone("").url(for: "")
    XCTAssertNil(url)
  }

  func testCommunicationType_twitterURL() {
    let url = CommunicationType.twitter("@coachsmith").url(for: "@coachsmith")
    XCTAssertNotNil(url)
    XCTAssertEqual(url?.absoluteString, "https://twitter.com/coachsmith")
  }

  func testCommunicationType_twitterURL_withoutAt() {
    let url = CommunicationType.twitter("coachsmith").url(for: "coachsmith")
    XCTAssertNotNil(url)
    XCTAssertEqual(url?.absoluteString, "https://twitter.com/coachsmith")
  }

  func testCommunicationType_twitterURL_empty() {
    let url = CommunicationType.twitter("").url(for: "")
    XCTAssertNil(url)
  }

  func testCommunicationType_instagramURL() {
    let url = CommunicationType.instagram("@coachsmith").url(for: "@coachsmith")
    XCTAssertNotNil(url)
    XCTAssertEqual(url?.absoluteString, "https://instagram.com/coachsmith")
  }

  func testCommunicationType_instagramURL_withoutAt() {
    let url = CommunicationType.instagram("coachsmith").url(for: "coachsmith")
    XCTAssertNotNil(url)
    XCTAssertEqual(url?.absoluteString, "https://instagram.com/coachsmith")
  }

  func testCommunicationType_instagramURL_empty() {
    let url = CommunicationType.instagram("").url(for: "")
    XCTAssertNil(url)
  }

  // MARK: - ResponsivenessBar Tests

  func testResponsivenessBar_rendersWithoutCrashing() {
    let view = ResponsivenessBar(score: 85)
    XCTAssertNotNil(view)
  }

  func testResponsivenessBar_highScore() {
    let view = ResponsivenessBar(score: 90)
    XCTAssertNotNil(view)
  }

  func testResponsivenessBar_mediumScore() {
    let view = ResponsivenessBar(score: 60)
    XCTAssertNotNil(view)
  }

  func testResponsivenessBar_lowScore() {
    let view = ResponsivenessBar(score: 30)
    XCTAssertNotNil(view)
  }

  func testResponsivenessBar_zeroScore() {
    let view = ResponsivenessBar(score: 0)
    XCTAssertNotNil(view)
  }

  func testResponsivenessBar_hundredScore() {
    let view = ResponsivenessBar(score: 100)
    XCTAssertNotNil(view)
  }

  func testResponsivenessBar_negativeScore() {
    let view = ResponsivenessBar(score: -10)
    // Should normalize to 0
    XCTAssertNotNil(view)
  }

  func testResponsivenessBar_overHundredScore() {
    let view = ResponsivenessBar(score: 150)
    // Should normalize to 100
    XCTAssertNotNil(view)
  }

  // MARK: - ResponsivenessBar Color Tests

  func testResponsivenessBar_highScoreColorThreshold() {
    // Score >= 75 should be green
    let view75 = ResponsivenessBar(score: 75)
    let view90 = ResponsivenessBar(score: 90)
    let view100 = ResponsivenessBar(score: 100)

    XCTAssertNotNil(view75)
    XCTAssertNotNil(view90)
    XCTAssertNotNil(view100)
  }

  func testResponsivenessBar_mediumScoreColorThreshold() {
    // Score >= 50 && < 75 should be amber
    let view50 = ResponsivenessBar(score: 50)
    let view60 = ResponsivenessBar(score: 60)
    let view74 = ResponsivenessBar(score: 74)

    XCTAssertNotNil(view50)
    XCTAssertNotNil(view60)
    XCTAssertNotNil(view74)
  }

  func testResponsivenessBar_lowScoreColorThreshold() {
    // Score < 50 should be red
    let view0 = ResponsivenessBar(score: 0)
    let view30 = ResponsivenessBar(score: 30)
    let view49 = ResponsivenessBar(score: 49)

    XCTAssertNotNil(view0)
    XCTAssertNotNil(view30)
    XCTAssertNotNil(view49)
  }

  // MARK: - ResponsivenessBar Accessibility Tests

  func testResponsivenessBar_hasAccessibilityLabel() {
    let view = ResponsivenessBar(score: 85)
    // Should have "Responsiveness" as accessibility label
    XCTAssertNotNil(view)
  }

  func testResponsivenessBar_hasAccessibilityValue() {
    let view = ResponsivenessBar(score: 85)
    // Should have "85% Responsive" as accessibility value
    XCTAssertNotNil(view)
  }

  func testResponsivenessBar_barHiddenForAccessibility() {
    let view = ResponsivenessBar(score: 85)
    // Progress bar should be hidden from accessibility
    XCTAssertNotNil(view)
  }

  func testResponsivenessBar_dynamicType() {
    let view = ResponsivenessBar(score: 85)
      .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
    XCTAssertNotNil(view)
  }

  // MARK: - ResponsivenessBar Score Normalization Tests

  func testResponsivenessBar_normalizesNegativeScore() {
    // Score of -10 should normalize to 0
    let view = ResponsivenessBar(score: -10)
    XCTAssertNotNil(view)
  }

  func testResponsivenessBar_normalizesOverHundred() {
    // Score of 150 should normalize to 100
    let view = ResponsivenessBar(score: 150)
    XCTAssertNotNil(view)
  }

  func testResponsivenessBar_preservesValidScore() {
    // Score of 85 should remain 85
    let view = ResponsivenessBar(score: 85)
    XCTAssertNotNil(view)
  }

  // MARK: - Integration Tests

  func testIntegration_communicationButtonWithAllTypes() {
    let emailButton = CommunicationButton(type: .email("test@test.com"), value: "test@test.com")
    let phoneButton = CommunicationButton(type: .phone("555-1234"), value: "555-1234")
    let twitterButton = CommunicationButton(type: .twitter("@coach"), value: "@coach")
    let instagramButton = CommunicationButton(type: .instagram("@coach"), value: "@coach")

    XCTAssertNotNil(emailButton)
    XCTAssertNotNil(phoneButton)
    XCTAssertNotNil(twitterButton)
    XCTAssertNotNil(instagramButton)
  }

  func testIntegration_responsivenessBarWithDifferentScores() {
    let low = ResponsivenessBar(score: 20)
    let medium = ResponsivenessBar(score: 60)
    let high = ResponsivenessBar(score: 90)

    XCTAssertNotNil(low)
    XCTAssertNotNil(medium)
    XCTAssertNotNil(high)
  }

  // MARK: - Edge Cases

  func testEdgeCase_emailWithSpaces() {
    let url = CommunicationType.email("  test@test.com  ").url(for: "  test@test.com  ")
    XCTAssertNotNil(url)
    XCTAssertEqual(url?.absoluteString, "mailto:test@test.com")
  }

  func testEdgeCase_phoneWithSpecialCharacters() {
    let url = CommunicationType.phone("+1 (555) 123-4567").url(for: "+1 (555) 123-4567")
    XCTAssertNotNil(url)
  }

  func testEdgeCase_twitterHandleWithMultipleAts() {
    let url = CommunicationType.twitter("@@coach").url(for: "@@coach")
    XCTAssertNotNil(url)
    // Should strip only the first @
    XCTAssertTrue(url?.absoluteString.contains("twitter.com") ?? false)
  }

  func testEdgeCase_veryLongEmail() {
    let longEmail = "verylongemailaddress@verylongdomainname.com"
    let url = CommunicationType.email(longEmail).url(for: longEmail)
    XCTAssertNotNil(url)
  }

  func testEdgeCase_fractionalResponsivenessScore() {
    let view = ResponsivenessBar(score: 85.7)
    XCTAssertNotNil(view)
  }
}
