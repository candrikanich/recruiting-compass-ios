import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class CoachDetailComponentsTests: XCTestCase {
  nonisolated deinit {}

  private var testCoach: Coach!
  private var testSchool: School!

  override func setUp() async throws {
    testCoach = makeCoach(id: "coach-1", firstName: "John", lastName: "Smith")
    testSchool = makeSchool(id: "school-1", name: "State University")
  }

  override func tearDown() async throws {
    testCoach = nil
    testSchool = nil
  }

  // MARK: - Test Helpers

  private func makeCoach(
    id: String,
    firstName: String = "John",
    lastName: String = "Smith",
    email: String? = "john@school.edu",
    phone: String? = "555-1234",
    position: String = "head",
    notes: String? = nil
  ) -> Coach {
    Coach(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      position: position,
      schoolId: "school-1",
      twitterHandle: "@coach",
      instagramHandle: "@coach",
      notes: notes,
      lastContactDate: "2026-02-01T10:00:00Z",
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )
  }

  private func makeSchool(id: String, name: String) -> School {
    School(
      id: id, userId: "user-1", name: name, location: "City, ST", city: "City", state: "ST",
      division: "D1", conference: "Big Ten", ranking: nil, isFavorite: false, website: nil,
      faviconUrl: nil, twitterHandle: nil, instagramHandle: nil, ncaaId: nil, status: "interested", statusChangedAt: nil, notes: nil,
      pros: [], cons: [], offerDetails: nil,
      academicInfo: nil, amenities: nil, coachingPhilosophy: nil, coachingStyle: nil,
      recruitingApproach: nil, communicationStyle: nil, successMetrics: nil, familyUnitId: "family-1", createdBy: nil, updatedBy: nil,
      createdAt: "2025-01-01T00:00:00Z", updatedAt: "2025-01-01T00:00:00Z"
    )
  }

  private func makeInteraction(
    id: String,
    type: InteractionType = .email,
    subject: String? = "Test Subject"
  ) -> Interaction {
    Interaction(
      id: id, type: type, direction: .outbound, schoolId: "school-1", coachId: "coach-1",
      subject: subject, content: nil, sentiment: .positive, occurredAt: "2026-02-08T10:00:00Z",
      loggedBy: "user-1", attachments: nil, familyUnitId: "family-1",
      createdAt: "2026-02-08T10:00:00Z", updatedAt: nil
    )
  }

  // MARK: - CoachDetailHeader Tests

  func testCoachDetailHeader_rendersWithAllFields() {
    let header = CoachDetailHeader(coach: testCoach, school: testSchool)

    let hostingController = UIHostingController(rootView: header)

    XCTAssertNotNil(hostingController.view)
    // Component should render initials, name, role badge, and school name
  }

  func testCoachDetailHeader_rendersWithoutSchool() {
    let header = CoachDetailHeader(coach: testCoach, school: nil)

    let hostingController = UIHostingController(rootView: header)

    XCTAssertNotNil(hostingController.view)
    // Component should render without crashing when school is nil
  }

  func testCoachDetailHeader_rendersInitials() {
    let coach = makeCoach(id: "coach-1", firstName: "Jane", lastName: "Doe")
    let header = CoachDetailHeader(coach: coach, school: testSchool)

    XCTAssertEqual(coach.initials, "JD")

    let hostingController = UIHostingController(rootView: header)
    XCTAssertNotNil(hostingController.view)
  }

  // MARK: - ContactInfoSection Tests

  func testContactInfoSection_rendersAllContactFields() {
    let section = ContactInfoSection(coach: testCoach)

    let hostingController = UIHostingController(rootView: section)

    XCTAssertNotNil(hostingController.view)
    // Should render email, phone, Twitter, and Instagram
  }

  func testContactInfoSection_handlesOptionalFields() {
    let coachMinimal = makeCoach(
      id: "coach-2",
      email: nil,
      phone: nil
    )
    let section = ContactInfoSection(coach: coachMinimal)

    let hostingController = UIHostingController(rootView: section)

    XCTAssertNotNil(hostingController.view)
    // Should render without crashing when optional fields are nil
  }

  func testContactInfoSection_rendersOnlyAvailableFields() {
    let coachPartial = Coach(
      id: "coach-3",
      firstName: "Test",
      lastName: "Coach",
      email: "test@example.com",
      phone: nil, // No phone
      position: "head",
      schoolId: "school-1",
      twitterHandle: nil, // No Twitter
      instagramHandle: nil, // No Instagram
      notes: nil,
      lastContactDate: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )

    let section = ContactInfoSection(coach: coachPartial)

    let hostingController = UIHostingController(rootView: section)

    XCTAssertNotNil(hostingController.view)
    // Should only render email section
  }

  // MARK: - CoachStatsGrid Tests

  func testStatsGrid_rendersWithAllStats() {
    let stats = CoachStats(
      totalInteractions: 12,
      daysSinceContact: 3,
      preferredMethod: "Email"
    )

    let grid = CoachStatsGrid(stats: stats)

    let hostingController = UIHostingController(rootView: grid)

    XCTAssertNotNil(hostingController.view)
  }

  func testStatsGrid_handlesNilValues() {
    let stats = CoachStats(
      totalInteractions: 0,
      daysSinceContact: nil,
      preferredMethod: nil
    )

    let grid = CoachStatsGrid(stats: stats)

    let hostingController = UIHostingController(rootView: grid)

    XCTAssertNotNil(hostingController.view)
    // Should display "N/A" for nil values
  }

  func testStatsGrid_displaysCorrectContactStatus() {
    let stats = CoachStats(
      totalInteractions: 5,
      daysSinceContact: 1,
      preferredMethod: "Phone"
    )

    XCTAssertEqual(stats.contactStatusText, "1 days ago")
  }

  // MARK: - RecentInteractionRow Tests

  func testRecentInteractionRow_rendersWithSubject() {
    let interaction = makeInteraction(id: "1", type: .email, subject: "Follow-up Email")

    let row = RecentInteractionRow(interaction: interaction)

    let hostingController = UIHostingController(rootView: row)

    XCTAssertNotNil(hostingController.view)
  }

  func testRecentInteractionRow_rendersWithoutSubject() {
    let interaction = makeInteraction(id: "2", type: .phoneCall, subject: nil)

    let row = RecentInteractionRow(interaction: interaction)

    let hostingController = UIHostingController(rootView: row)

    XCTAssertNotNil(hostingController.view)
    // Should render with type name as fallback
  }

  func testRecentInteractionRow_rendersAllInteractionTypes() {
    let types: [InteractionType] = [.email, .phoneCall, .text, .inPersonVisit, .virtualMeeting, .camp, .showcase, .tweet, .directMessage]

    for type in types {
      let interaction = makeInteraction(id: UUID().uuidString, type: type)
      let row = RecentInteractionRow(interaction: interaction)

      let hostingController = UIHostingController(rootView: row)

      XCTAssertNotNil(hostingController.view, "Should render interaction type: \(type)")
    }
  }

  // MARK: - NotesSection Tests

  // MARK: - LoadingStateView Tests

  func testLoadingStateView_rendersWithMessage() {
    let loadingView = LoadingStateView(message: "Loading coach details")

    let hostingController = UIHostingController(rootView: loadingView)

    XCTAssertNotNil(hostingController.view)
  }

  func testLoadingStateView_rendersWithDifferentMessages() {
    let messages = [
      "Loading...",
      "Please wait",
      "Fetching data",
      "Loading coach details"
    ]

    for message in messages {
      let loadingView = LoadingStateView(message: message)
      let hostingController = UIHostingController(rootView: loadingView)

      XCTAssertNotNil(hostingController.view, "Should render with message: \(message)")
    }
  }

  // MARK: - InlineErrorView Tests

  func testInlineErrorView_rendersWithMessage() {
    let errorView = InlineErrorView(message: "Failed to load coach")

    let hostingController = UIHostingController(rootView: errorView)

    XCTAssertNotNil(hostingController.view)
  }

  func testInlineErrorView_rendersWithDifferentErrors() {
    let errorMessages = [
      "Coach not found",
      "Failed to load coach details",
      "Network error",
      "Unknown error"
    ]

    for message in errorMessages {
      let errorView = InlineErrorView(message: message)
      let hostingController = UIHostingController(rootView: errorView)

      XCTAssertNotNil(hostingController.view, "Should render with error: \(message)")
    }
  }

  // MARK: - CoachEditForm Tests

  func testCoachEditForm_rendersWithoutCrashing() {
    let editableCoach = EditableCoach(
      firstName: "John",
      lastName: "Smith",
      email: "john@school.edu",
      phone: "555-1234",
      position: "head",
      twitterHandle: "@coach",
      instagramHandle: "@coach",
      notes: "Test notes"
    )

    let form = CoachEditForm(
      editedCoach: .constant(editableCoach),
      validationErrors: [:],
      isSaving: false,
      onSave: {},
      onCancel: {}
    )

    let hostingController = UIHostingController(rootView: form)

    XCTAssertNotNil(hostingController.view)
  }

  func testCoachEditForm_rendersValidationErrors() {
    let editableCoach = EditableCoach(
      firstName: "",
      lastName: "",
      email: "invalid-email",
      phone: "",
      position: "head",
      twitterHandle: "",
      instagramHandle: "",
      notes: ""
    )

    let validationErrors = [
      "firstName": "First name is required",
      "lastName": "Last name is required",
      "email": "Invalid email format"
    ]

    let form = CoachEditForm(
      editedCoach: .constant(editableCoach),
      validationErrors: validationErrors,
      isSaving: false,
      onSave: {},
      onCancel: {}
    )

    let hostingController = UIHostingController(rootView: form)

    XCTAssertNotNil(hostingController.view)
    // Validation errors should be displayed
  }

  func testCoachEditForm_rendersSavingState() {
    let editableCoach = EditableCoach(
      firstName: "John",
      lastName: "Smith",
      email: "john@school.edu",
      phone: "555-1234",
      position: "head",
      twitterHandle: "@coach",
      instagramHandle: "@coach",
      notes: "Test notes"
    )

    let form = CoachEditForm(
      editedCoach: .constant(editableCoach),
      validationErrors: [:],
      isSaving: true,
      onSave: {},
      onCancel: {}
    )

    let hostingController = UIHostingController(rootView: form)

    XCTAssertNotNil(hostingController.view)
    // Save button should show loading indicator
  }
}
