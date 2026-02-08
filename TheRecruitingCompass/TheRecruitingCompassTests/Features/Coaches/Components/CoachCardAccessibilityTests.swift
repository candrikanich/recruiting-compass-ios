import XCTest
@testable import TheRecruitingCompass

final class CoachCardAccessibilityTests: XCTestCase {

  // MARK: - Test Helpers

  private func makeCoach(
    email: String? = "john@school.edu",
    phone: String? = "555-1234",
    position: String? = "head",
    twitterHandle: String? = nil,
    instagramHandle: String? = nil,
    responsivenessScore: Double = 85
  ) -> Coach {
    Coach(
      id: "coach-1",
      firstName: "John",
      lastName: "Smith",
      email: email,
      phone: phone,
      position: position,
      schoolId: "school-1",
      twitterHandle: twitterHandle,
      instagramHandle: instagramHandle,
      notes: nil,
      responsivenessScore: responsivenessScore,
      lastContactDate: "2026-02-01T00:00:00Z",
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )
  }

  // MARK: - Coach Model Accessibility Data

  func testCoachInitials_correctlyComputed() {
    let coach = makeCoach()
    XCTAssertEqual(coach.initials, "JS")
  }

  func testCoachRole_mapsFromPosition() {
    let headCoach = makeCoach(position: "head")
    XCTAssertEqual(headCoach.role, .head)
    XCTAssertEqual(headCoach.role.displayName, "Head Coach")

    let assistantCoach = makeCoach(position: "assistant")
    XCTAssertEqual(assistantCoach.role, .assistant)

    let recruitingCoach = makeCoach(position: "recruiting")
    XCTAssertEqual(recruitingCoach.role, .recruiting)
  }

  func testCoachRole_unknownPosition_defaultsToAssistant() {
    let coach = makeCoach(position: "unknown")
    XCTAssertEqual(coach.role, .assistant)
  }

  func testCoachRole_nilPosition_defaultsToAssistant() {
    let coach = makeCoach(position: nil)
    XCTAssertEqual(coach.role, .assistant)
  }

  // MARK: - Responsiveness Level Tests

  func testResponsivenessLevel_highRange() {
    XCTAssertTrue(ResponsivenessLevel.high.matches(score: 75))
    XCTAssertTrue(ResponsivenessLevel.high.matches(score: 100))
    XCTAssertFalse(ResponsivenessLevel.high.matches(score: 74))
  }

  func testResponsivenessLevel_mediumRange() {
    XCTAssertTrue(ResponsivenessLevel.medium.matches(score: 50))
    XCTAssertTrue(ResponsivenessLevel.medium.matches(score: 74))
    XCTAssertFalse(ResponsivenessLevel.medium.matches(score: 49))
  }

  func testResponsivenessLevel_lowRange() {
    XCTAssertTrue(ResponsivenessLevel.low.matches(score: 0))
    XCTAssertTrue(ResponsivenessLevel.low.matches(score: 49))
    XCTAssertFalse(ResponsivenessLevel.low.matches(score: 50))
  }

  // MARK: - Communication Type Tests

  func testCommunicationType_emailURL() {
    let url = CommunicationType.email("test@school.edu").url(for: "test@school.edu")
    XCTAssertEqual(url?.absoluteString, "mailto:test@school.edu")
  }

  func testCommunicationType_phoneURL() {
    let url = CommunicationType.phone("555-1234").url(for: "555-1234")
    XCTAssertEqual(url?.absoluteString, "sms:555-1234")
  }

  func testCommunicationType_twitterURL_stripsAt() {
    let url = CommunicationType.twitter("@coach").url(for: "@coach")
    XCTAssertEqual(url?.absoluteString, "https://twitter.com/coach")
  }

  func testCommunicationType_instagramURL_stripsAt() {
    let url = CommunicationType.instagram("@coach").url(for: "@coach")
    XCTAssertEqual(url?.absoluteString, "https://instagram.com/coach")
  }

  // MARK: - CommunicationType Accessibility Labels

  func testCommunicationType_accessibilityLabels() {
    XCTAssertEqual(CommunicationType.email("").accessibilityLabel, "Email coach")
    XCTAssertEqual(CommunicationType.phone("").accessibilityLabel, "Text coach")
    XCTAssertEqual(CommunicationType.twitter("").accessibilityLabel, "View Twitter profile")
    XCTAssertEqual(CommunicationType.instagram("").accessibilityLabel, "View Instagram profile")
  }

  // MARK: - CoachFilters Tests

  func testCoachFilters_hasActiveFilters_false() {
    let filters = CoachFilters()
    XCTAssertFalse(filters.hasActiveFilters)
  }

  func testCoachFilters_hasActiveFilters_true() {
    var filters = CoachFilters()
    filters.role = .head
    XCTAssertTrue(filters.hasActiveFilters)
  }

  func testCoachFilters_activeFilterCount() {
    var filters = CoachFilters()
    XCTAssertEqual(filters.activeFilterCount, 0)

    filters.role = .head
    filters.lastContactDays = 30
    filters.responsivenessLevel = .high
    XCTAssertEqual(filters.activeFilterCount, 3)
  }

  // MARK: - Coach Full Name

  func testCoachFullName() {
    let coach = makeCoach()
    XCTAssertEqual(coach.fullName, "John Smith")
  }

  // MARK: - Last Contact Date Parsing

  func testLastContactDate_validDate() {
    let coach = makeCoach()
    XCTAssertNotNil(coach.lastContactDateParsed)
  }

  func testLastContactDate_nilDate() {
    let coach = Coach(
      id: "1",
      firstName: "John",
      lastName: "Smith",
      email: nil,
      phone: nil,
      position: nil,
      schoolId: "s1",
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil,
      responsivenessScore: 0,
      lastContactDate: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2025-01-01T00:00:00Z"
    )
    XCTAssertNil(coach.lastContactDateParsed)
  }
}
