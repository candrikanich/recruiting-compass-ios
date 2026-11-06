import XCTest
@testable import TheRecruitingCompass

final class CoachChannelTests: XCTestCase {
  private func makeCoach(email: String? = "jo@u.edu") -> Coach {
    Coach(
      id: "1", firstName: "Jo", lastName: "Coach", email: email, phone: "555-0100",
      schoolId: "s1", twitterHandle: "@jo", instagramHandle: "@jo",
      createdAt: "2025-01-01T00:00:00Z", updatedAt: "2025-01-01T00:00:00Z"
    )
  }

  func test_outreachEnabled_showsEveryChannelTheCoachHas() {
    XCTAssertEqual(
      CoachChannel.visible(for: makeCoach(), outreachEnabled: true),
      [.email, .text, .call, .twitter, .instagram]
    )
  }

  // Email/text/Instagram outreach is only safe inside the Quick Communication flow, which runs the
  // guardian lock; with the flow switched off those entry points must disappear, not fall back.
  func test_outreachDisabled_hidesEmailTextAndInstagram_keepsCallAndTwitter() {
    XCTAssertEqual(
      CoachChannel.visible(for: makeCoach(), outreachEnabled: false),
      [.call, .twitter]
    )
  }

  func test_channelsAbsentFromTheCoach_stayAbsent() {
    XCTAssertFalse(CoachChannel.visible(for: makeCoach(email: nil), outreachEnabled: true).contains(.email))
  }
}
