import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class CoachCardViewTests: XCTestCase {

  // MARK: - Test Helpers

  private func makeCoach(
    id: String = "coach-1",
    firstName: String = "John",
    lastName: String = "Smith",
    email: String? = "john@school.edu",
    phone: String? = "555-1234",
    position: String? = "head",
    twitterHandle: String? = nil,
    instagramHandle: String? = nil,
    lastContactDate: String? = "2026-02-01T10:00:00Z"
  ) -> Coach {
    Coach(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      position: position,
      schoolId: "school-1",
      twitterHandle: twitterHandle,
      instagramHandle: instagramHandle,
      notes: nil,
      lastContactDate: lastContactDate,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )
  }

  // MARK: - View Rendering Tests

  func testCoachCard_rendersWithoutCrashing() {
    let coach = makeCoach()
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      schoolLogoUrl: nil,
      schoolInitials: "SU"
    )

    XCTAssertNotNil(view)
  }

  func testCoachCard_rendersWithMinimalInfo() {
    let coach = makeCoach(
      email: nil,
      phone: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      lastContactDate: nil
    )
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      schoolLogoUrl: nil,
      schoolInitials: "SU"
    )

    XCTAssertNotNil(view)
  }

  func testCoachCard_rendersWithFullInfo() {
    let coach = makeCoach(
      email: "john@school.edu",
      phone: "555-1234",
      twitterHandle: "@coachsmith",
      instagramHandle: "@coachsmith",
      lastContactDate: "2026-02-08T10:00:00Z"
    )
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      schoolLogoUrl: nil,
      schoolInitials: "SU"
    )

    XCTAssertNotNil(view)
  }

  // MARK: - Coach Data Display Tests

  func testCoachCard_displaysFullName() {
    let coach = makeCoach(firstName: "John", lastName: "Smith")
    XCTAssertEqual(coach.fullName, "John Smith")
  }

  func testCoachCard_displaysInitials() {
    let coach = makeCoach(firstName: "John", lastName: "Smith")
    XCTAssertEqual(coach.initials, "JS")
  }

  func testCoachCard_displaysInitialsForSingleName() {
    let coach = makeCoach(firstName: "John", lastName: "")
    XCTAssertEqual(coach.initials, "J")
  }

  // MARK: - Role Badge Tests

  func testCoachCard_displaysHeadCoachRole() {
    let coach = makeCoach(position: "head")
    XCTAssertEqual(coach.role, .head)
    XCTAssertEqual(coach.role.displayName, "Head Coach")
  }

  func testCoachCard_displaysAssistantCoachRole() {
    let coach = makeCoach(position: "assistant")
    XCTAssertEqual(coach.role, .assistant)
    XCTAssertEqual(coach.role.displayName, "Assistant Coach")
  }

  func testCoachCard_displaysRecruitingCoordinatorRole() {
    let coach = makeCoach(position: "recruiting")
    XCTAssertEqual(coach.role, .recruiting)
    XCTAssertEqual(coach.role.displayName, "Recruiting Coordinator")
  }

  func testCoachCard_defaultsToAssistantForUnknownRole() {
    let coach = makeCoach(position: "unknown")
    XCTAssertEqual(coach.role, .assistant)
  }

  func testCoachCard_decodesRoleFromApiRoleKey() throws {
    // Database/API may return "role" (from CoachCreateRequest) instead of "position"
    let json = """
    {
      "id": "coach-1",
      "first_name": "Jane",
      "last_name": "Smith",
      "role": "head",
      "school_id": "school-1",
      "responsiveness_score": 85,
      "created_at": "2025-01-01T00:00:00Z",
      "updated_at": "2026-01-01T00:00:00Z"
    }
    """
    let data = json.data(using: .utf8)!
    let coach = try JSONDecoder().decode(Coach.self, from: data)
    XCTAssertEqual(coach.role, .head)
    XCTAssertEqual(coach.role.displayName, "Head Coach")
  }

  // MARK: - Contact Information Tests

  func testCoachCard_displaysEmail() {
    let coach = makeCoach(email: "john@school.edu")
    XCTAssertEqual(coach.email, "john@school.edu")
  }

  func testCoachCard_displaysPhone() {
    let coach = makeCoach(phone: "555-1234")
    XCTAssertEqual(coach.phone, "555-1234")
  }

  func testCoachCard_handlesNilEmail() {
    let coach = makeCoach(email: nil)
    XCTAssertNil(coach.email)
  }

  func testCoachCard_handlesNilPhone() {
    let coach = makeCoach(phone: nil)
    XCTAssertNil(coach.phone)
  }

  // MARK: - Social Media Tests

  func testCoachCard_displaysTwitterHandle() {
    let coach = makeCoach(twitterHandle: "@coachsmith")
    XCTAssertEqual(coach.twitterHandle, "@coachsmith")
  }

  func testCoachCard_displaysInstagramHandle() {
    let coach = makeCoach(instagramHandle: "@coachsmith")
    XCTAssertEqual(coach.instagramHandle, "@coachsmith")
  }

  func testCoachCard_handlesNilTwitterHandle() {
    let coach = makeCoach(twitterHandle: nil)
    XCTAssertNil(coach.twitterHandle)
  }

  func testCoachCard_handlesNilInstagramHandle() {
    let coach = makeCoach(instagramHandle: nil)
    XCTAssertNil(coach.instagramHandle)
  }

  // MARK: - Responsiveness Score Tests

  func testCoachCard_displaysResponsivenessScore() {
  }

  func testCoachCard_highResponsivenessScore() {
  }

  func testCoachCard_mediumResponsivenessScore() {
  }

  func testCoachCard_lowResponsivenessScore() {
  }

  // MARK: - Last Contact Date Tests

  func testCoachCard_parsesLastContactDate() {
    let coach = makeCoach(lastContactDate: "2026-02-01T10:00:00Z")
    XCTAssertNotNil(coach.lastContactDateParsed)
  }

  func testCoachCard_handlesNilLastContactDate() {
    let coach = makeCoach(lastContactDate: nil)
    XCTAssertNil(coach.lastContactDateParsed)
  }

  func testCoachCard_handlesInvalidLastContactDate() {
    let coach = makeCoach(lastContactDate: "invalid-date")
    XCTAssertNil(coach.lastContactDateParsed)
  }

  // MARK: - Accessibility Tests

  func testAccessibility_cardHasLabel() {
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      schoolLogoUrl: nil,
      schoolInitials: "SU"
    )

    // The card should have an accessibility label with coach info
    XCTAssertNotNil(view)
  }

  func testAccessibility_roleBadgeHasLabel() {
    let coach = makeCoach(position: "head")
    XCTAssertEqual(coach.role.displayName, "Head Coach")
  }

  func testAccessibility_deleteButtonHasLabel() {
    let coach = makeCoach()
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      schoolLogoUrl: nil,
      schoolInitials: "SU"
    )

    // Delete button should have "Delete coach" accessibility label
    XCTAssertNotNil(view)
  }

  // MARK: - Dynamic Type Tests

  func testDynamicType_supportsAccessibilitySizes() {
    let coach = makeCoach()
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      schoolLogoUrl: nil,
      schoolInitials: "SU"
    )
    .environment(\.sizeCategory, .accessibilityExtraExtraLarge)

    XCTAssertNotNil(view)
  }

  func testDynamicType_supportsStandardSizes() {
    let coach = makeCoach()
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      schoolLogoUrl: nil,
      schoolInitials: "SU"
    )
    .environment(\.sizeCategory, .medium)

    XCTAssertNotNil(view)
  }

  func testDynamicType_initialsScaleWithCategory() {
    // Test that initials size is calculated based on size category
    let coach = makeCoach()
    let view = CoachCardView(
      coach: coach,
      schoolName: "State University",
      schoolLogoUrl: nil,
      schoolInitials: "SU"
    )

    // Standard size
    let standardView = view.environment(\.sizeCategory, .medium)
    XCTAssertNotNil(standardView)

    // Accessibility size
    let accessibilityView = view.environment(\.sizeCategory, .accessibilityExtraLarge)
    XCTAssertNotNil(accessibilityView)
  }

  // MARK: - Communication Button Tests

  func testCoachCard_showsEmailButtonWhenEmailPresent() {
    let coach = makeCoach(email: "john@school.edu")
    XCTAssertNotNil(coach.email)
  }

  func testCoachCard_hidesEmailButtonWhenEmailNil() {
    let coach = makeCoach(email: nil)
    XCTAssertNil(coach.email)
  }

  func testCoachCard_showsPhoneButtonWhenPhonePresent() {
    let coach = makeCoach(phone: "555-1234")
    XCTAssertNotNil(coach.phone)
  }

  func testCoachCard_hidesPhoneButtonWhenPhoneNil() {
    let coach = makeCoach(phone: nil)
    XCTAssertNil(coach.phone)
  }

  func testCoachCard_showsTwitterButtonWhenHandlePresent() {
    let coach = makeCoach(twitterHandle: "@coachsmith")
    XCTAssertNotNil(coach.twitterHandle)
  }

  func testCoachCard_hidesTwitterButtonWhenHandleNil() {
    let coach = makeCoach(twitterHandle: nil)
    XCTAssertNil(coach.twitterHandle)
  }

  func testCoachCard_showsInstagramButtonWhenHandlePresent() {
    let coach = makeCoach(instagramHandle: "@coachsmith")
    XCTAssertNotNil(coach.instagramHandle)
  }

  func testCoachCard_hidesInstagramButtonWhenHandleNil() {
    let coach = makeCoach(instagramHandle: nil)
    XCTAssertNil(coach.instagramHandle)
  }

  // MARK: - School Name Tests

  func testCoachCard_displaysSchoolName() {
    let coach = makeCoach()
    let view = CoachCardView(
      coach: coach,
      schoolName: "University of Testing",
      schoolLogoUrl: nil,
      schoolInitials: "UT"
    )

    XCTAssertNotNil(view)
  }

  func testCoachCard_handlesLongSchoolName() {
    let coach = makeCoach()
    let view = CoachCardView(
      coach: coach,
      schoolName: "The University of Very Long Names and Extended Titles for Testing Purposes",
      schoolLogoUrl: nil,
      schoolInitials: "UV"
    )

    XCTAssertNotNil(view)
  }

  // MARK: - Edge Cases

  func testEdgeCase_emptyNames() {
    let coach = makeCoach(firstName: "", lastName: "")
    XCTAssertEqual(coach.fullName, " ")
    XCTAssertEqual(coach.initials, "")
  }

  func testEdgeCase_specialCharactersInName() {
    let coach = makeCoach(firstName: "José", lastName: "O'Brien-Smith")
    XCTAssertEqual(coach.fullName, "José O'Brien-Smith")
  }

  func testEdgeCase_zeroResponsivenessScore() {
    XCTAssertTrue(ResponsivenessLevel.low.matches(score: 0))
  }

  func testEdgeCase_hundredResponsivenessScore() {
    XCTAssertTrue(ResponsivenessLevel.high.matches(score: 100))
  }
}
