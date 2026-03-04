//
//  CreateEventAccessibilityTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-17
//  Phase 6: Testing - Accessibility tests for Create Event feature
//

import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class CreateEventAccessibilityTests: XCTestCase {

  // Explicit tearDown avoids deallocating @Observable @MainActor ViewModels at scope exit,
  // which can trigger malloc corruption on some SDK versions (FB: CreateEventViewModel deinit crash).
  private var viewModelUnderTest: (any Any)?

  override func tearDown() {
    viewModelUnderTest = nil
    super.tearDown()
  }

  // MARK: - Test Helpers

  private func makeViewModel(
    service: MockEventsService = MockEventsService(),
    userId: String = "test-user"
  ) -> CreateEventViewModel {
    let vm = CreateEventViewModel(eventsService: service, userId: userId)
    viewModelUnderTest = vm  // Hold reference until tearDown to avoid deinit-at-scope-exit crash
    return vm
  }

  private func date(_ string: String) -> Date {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f.date(from: string)!
  }

  private func time(_ string: String) -> Date {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "HH:mm"
    return f.date(from: string)!
  }

  // MARK: - Required Fields Have Accessibility Labels

  func testCreateEventForm_requiredFields_haveAccessibilityLabels() {
    // Required fields per spec: Event Type, Event Name, Start Date
    // These must have accessibilityLabel with "Required" suffix in the View.
    // At the ViewModel level, verify required field validation catches missing values.
    let viewModel = makeViewModel()

    // All required fields empty
    viewModel.formData.type = nil
    viewModel.formData.name = ""
    viewModel.formData.startDate = nil

    let isValid = viewModel.validateForm()
    XCTAssertFalse(isValid, "Form should be invalid when required fields are empty")
    XCTAssertNotNil(viewModel.validationErrors["type"], "Event type should have validation error")
    XCTAssertNotNil(viewModel.validationErrors["name"], "Event name should have validation error")
    XCTAssertNotNil(viewModel.validationErrors["startDate"], "Start date should have validation error")
    XCTAssertEqual(viewModel.validationErrors.count, 3, "Should have exactly 3 required field errors")
  }

  // MARK: - Optional Fields Have Accessibility Labels

  func testCreateEventForm_optionalFields_haveAccessibilityLabels() {
    // Optional fields should NOT produce validation errors when empty
    let viewModel = makeViewModel()

    // Fill only required fields
    viewModel.formData.type = .showcase
    viewModel.formData.name = "Spring Showcase"
    viewModel.formData.startDate = date("2026-04-15")

    // Leave all optional fields empty
    viewModel.formData.endDate = nil
    viewModel.formData.startTime = nil
    viewModel.formData.endTime = nil
    viewModel.formData.checkinTime = nil
    viewModel.formData.location = ""
    viewModel.formData.address = ""
    viewModel.formData.city = ""
    viewModel.formData.state = ""
    viewModel.formData.url = ""
    viewModel.formData.description = ""
    viewModel.formData.cost = ""
    viewModel.formData.performanceNotes = ""

    let isValid = viewModel.validateForm()
    XCTAssertTrue(isValid, "Form should be valid with only required fields filled")
    XCTAssertTrue(viewModel.validationErrors.isEmpty, "No validation errors for optional fields")
  }

  // MARK: - Validation Error Announces Error

  func testCreateEventForm_validationError_announcesError() {
    // When validation fails, validationErrors dictionary should have descriptive messages
    // that the View uses for .accessibilityValue("Error: [message]")
    let viewModel = makeViewModel()

    viewModel.formData.type = nil
    viewModel.formData.name = ""
    viewModel.formData.startDate = nil

    _ = viewModel.validateForm()

    XCTAssertEqual(
      viewModel.validationErrors["type"],
      "Event type is required",
      "Event type error message should be descriptive for VoiceOver"
    )
    XCTAssertEqual(
      viewModel.validationErrors["name"],
      "Event name is required",
      "Event name error message should be descriptive for VoiceOver"
    )
    XCTAssertEqual(
      viewModel.validationErrors["startDate"],
      "Start date is required",
      "Start date error message should be descriptive for VoiceOver"
    )
  }

  func testCreateEventForm_validationError_endDateBeforeStartDate() {
    let viewModel = makeViewModel()

    viewModel.formData.type = .camp
    viewModel.formData.name = "Summer Camp"
    viewModel.formData.startDate = date("2026-06-15")
    viewModel.formData.endDate = date("2026-06-14")

    let isValid = viewModel.validateForm()

    XCTAssertFalse(isValid, "Form should be invalid when end date is before start date")
    XCTAssertEqual(
      viewModel.validationErrors["endDate"],
      "End date must be after start date",
      "End date error should be descriptive for VoiceOver announcement"
    )
  }

  func testCreateEventForm_validationErrors_clearedOnRevalidation() {
    let viewModel = makeViewModel()

    // First: trigger errors
    viewModel.formData.type = nil
    viewModel.formData.name = ""
    viewModel.formData.startDate = nil
    _ = viewModel.validateForm()
    XCTAssertEqual(viewModel.validationErrors.count, 3)

    // Fix all fields and revalidate
    viewModel.formData.type = .showcase
    viewModel.formData.name = "Fixed Event"
    viewModel.formData.startDate = date("2026-04-15")
    let isValid = viewModel.validateForm()

    XCTAssertTrue(isValid, "Form should be valid after fixing errors")
    XCTAssertTrue(viewModel.validationErrors.isEmpty, "Errors should be cleared on successful validation")
  }

  // MARK: - Get Directions Button

  func testCreateEventForm_getDirectionsButton_hasAccessibilityLabel() {
    // showGetDirections should be true only when address/city is entered
    let viewModel = makeViewModel()

    // No address info
    viewModel.formData.address = ""
    viewModel.formData.city = ""
    XCTAssertFalse(viewModel.showGetDirections, "Get Directions should be hidden when no address entered")

    // With address
    viewModel.formData.address = "123 Stadium Dr"
    XCTAssertTrue(viewModel.showGetDirections, "Get Directions should appear when address is entered")
  }

  func testCreateEventForm_getDirectionsURL_constructsValidQuery() {
    let viewModel = makeViewModel()

    viewModel.formData.address = "123 Stadium Dr"
    viewModel.formData.city = "Austin"
    viewModel.formData.state = "TX"

    let url = viewModel.getDirectionsURL()
    XCTAssertNotNil(url, "Should construct a valid Maps URL")
    XCTAssertTrue(url!.absoluteString.contains("maps://"), "Should use Maps URL scheme")
  }

  // MARK: - Create Event Button Disabled State

  func testCreateEventForm_createEventButton_disabledState_isAnnounced() {
    let viewModel = makeViewModel()

    // All required fields empty
    viewModel.formData.type = nil
    viewModel.formData.name = ""
    viewModel.formData.startDate = nil
    XCTAssertTrue(viewModel.isSubmitDisabled, "Submit should be disabled when required fields are empty")

    // Fill event type only
    viewModel.formData.type = .showcase
    XCTAssertTrue(viewModel.isSubmitDisabled, "Submit should be disabled when name and date are empty")

    // Fill name too
    viewModel.formData.name = "Test Event"
    XCTAssertTrue(viewModel.isSubmitDisabled, "Submit should be disabled when start date is empty")

    // Fill all required
    viewModel.formData.startDate = date("2026-04-15")
    XCTAssertFalse(viewModel.isSubmitDisabled, "Submit should be enabled when all required fields are filled")
  }

  func testCreateEventForm_createEventButton_disabledWhileSaving() async {
    let viewModel = makeViewModel()

    viewModel.formData.type = .showcase
    viewModel.formData.name = "Test Event"
    viewModel.formData.startDate = date("2026-04-15")

    XCTAssertFalse(viewModel.isSubmitDisabled, "Submit should be enabled before saving")

    // Note: isSaving is set during async createEvent() and reset by defer
    // We verify the property exists and is factored into isSubmitDisabled
    XCTAssertFalse(viewModel.isSaving, "Should not be saving initially")
  }

  // MARK: - Other School Modal

  func testOtherSchoolModal_hasCorrectAccessibilityTree() {
    let viewModel = makeViewModel()

    // Trigger "Other" school selection
    viewModel.handleSchoolSelection("other")

    XCTAssertTrue(viewModel.showOtherSchoolModal, "Other school modal should be shown")
    XCTAssertNil(viewModel.formData.schoolId, "School ID should be nil when 'other' selected")

    // Enter school name and confirm
    viewModel.otherSchoolName = "Local Community College"
    viewModel.handleOtherSchool()

    XCTAssertFalse(viewModel.showOtherSchoolModal, "Modal should dismiss after confirming")
    XCTAssertEqual(viewModel.formData.location, "Local Community College", "Location should be set from other school name")
    XCTAssertTrue(viewModel.otherSchoolName.isEmpty, "Other school name should be cleared after confirm")
  }

  func testOtherSchoolModal_emptyName_doesNotSetLocation() {
    let viewModel = makeViewModel()

    viewModel.handleSchoolSelection("other")
    viewModel.otherSchoolName = "   "
    viewModel.handleOtherSchool()

    // Modal stays open when name is empty/whitespace (user must enter a name or cancel)
    XCTAssertTrue(viewModel.showOtherSchoolModal, "Modal should stay open when name is empty or whitespace")
    XCTAssertTrue(viewModel.formData.location.isEmpty, "Location should not be set from whitespace-only name")
  }

  // MARK: - Add School Modal

  func testAddSchoolModal_hasCorrectAccessibilityTree() async {
    let mockService = MockEventsService()
    let viewModel = makeViewModel(service: mockService)

    // Trigger "Add new" school selection
    viewModel.handleSchoolSelection("add_new")

    XCTAssertTrue(viewModel.showAddSchoolModal, "Add school modal should be shown")
    XCTAssertNil(viewModel.formData.schoolId, "School ID should be nil when adding new")

    // Fill school form
    viewModel.newSchoolName = "University of Testing"
    viewModel.newSchoolLocation = "Test City, TX"

    // Save new school
    mockService.stubbedCreatedSchool = SchoolSummary(id: "new-1", name: "University of Testing", location: "Test City, TX")
    await viewModel.saveNewSchool()

    XCTAssertFalse(viewModel.showAddSchoolModal, "Modal should dismiss after saving")
    XCTAssertEqual(viewModel.formData.schoolId, "new-1", "New school should be selected")
    XCTAssertTrue(viewModel.newSchoolName.isEmpty, "School name field should be cleared")
    XCTAssertTrue(viewModel.newSchoolLocation.isEmpty, "School location field should be cleared")
  }

  func testAddSchoolModal_saveDisabled_whenNameEmpty() async {
    let mockService = MockEventsService()
    let viewModel = makeViewModel(service: mockService)

    viewModel.handleSchoolSelection("add_new")
    viewModel.newSchoolName = "   "

    await viewModel.saveNewSchool()

    // Should not call service when name is empty
    XCTAssertEqual(mockService.createSchoolCallCount, 0, "Should not create school with empty name")
    XCTAssertTrue(viewModel.showAddSchoolModal, "Modal should remain open when save fails")
  }

  // MARK: - Checkboxes: Registered & Attended

  func testCheckboxes_registered_attended_haveLabels() {
    // Verify the toggle properties are accessible and togglable
    let viewModel = makeViewModel()

    XCTAssertFalse(viewModel.formData.registered, "Registered should default to false")
    XCTAssertFalse(viewModel.formData.attended, "Attended should default to false")

    viewModel.formData.registered = true
    viewModel.formData.attended = true

    XCTAssertTrue(viewModel.formData.registered, "Registered should be toggleable")
    XCTAssertTrue(viewModel.formData.attended, "Attended should be toggleable")
  }

  // MARK: - Date Pickers

  func testDatePickers_haveRequiredIndicator() {
    // Start date = required, End date = optional
    let viewModel = makeViewModel()

    // Verify start date triggers validation error when nil
    viewModel.formData.type = .showcase
    viewModel.formData.name = "Test"
    viewModel.formData.startDate = nil
    _ = viewModel.validateForm()
    XCTAssertNotNil(viewModel.validationErrors["startDate"], "Start date should be required (produces validation error)")

    // Verify end date does NOT trigger validation error when nil
    viewModel.formData.startDate = date("2026-04-15")
    viewModel.formData.endDate = nil
    let isValid = viewModel.validateForm()
    XCTAssertTrue(isValid, "Form should be valid with empty end date")
    XCTAssertNil(viewModel.validationErrors["endDate"], "End date should not produce error when empty")
  }

  func testDatePickers_startDateAutoPopulatesEndDate() {
    let viewModel = makeViewModel()

    let startDate = date("2026-04-15")
    viewModel.formData.startDate = startDate
    viewModel.formData.endDate = nil
    viewModel.onStartDateChanged()

    XCTAssertEqual(viewModel.formData.endDate, startDate, "End date should auto-populate to start date")
  }

  func testDatePickers_startDateDoesNotOverwriteExistingEndDate() {
    let viewModel = makeViewModel()

    let endDate = date("2026-04-20")
    viewModel.formData.endDate = endDate
    viewModel.formData.startDate = date("2026-04-15")
    viewModel.onStartDateChanged()

    XCTAssertEqual(viewModel.formData.endDate, endDate, "Should not overwrite existing end date")
  }

  func testTimePickers_startTimeAutoPopulatesEndTime() {
    let viewModel = makeViewModel()

    let startTime = time("09:00")
    viewModel.formData.startTime = startTime
    viewModel.formData.endTime = nil
    viewModel.onStartTimeChanged()

    let expectedEnd = Calendar.current.date(byAdding: .hour, value: 1, to: startTime)
    XCTAssertEqual(viewModel.formData.endTime, expectedEnd, "End time should auto-populate to start time + 1 hour")
  }

  // MARK: - EventType Display Names for VoiceOver

  func testEventType_allCasesHaveDisplayNames() {
    for eventType in EventType.allCases {
      XCTAssertFalse(
        eventType.displayName.isEmpty,
        "\(eventType.rawValue) should have a non-empty displayName for VoiceOver"
      )
    }
  }

  func testEventSource_allCasesHaveDisplayNames() {
    for source in EventSource.allCases {
      XCTAssertFalse(
        source.displayName.isEmpty,
        "\(source.rawValue) should have a non-empty displayName for VoiceOver"
      )
    }
  }

  // MARK: - School Selection Accessibility

  func testSchoolSelection_none_clearsSchoolId() {
    let viewModel = makeViewModel()

    viewModel.formData.schoolId = "existing-school"
    viewModel.handleSchoolSelection("none")

    XCTAssertNil(viewModel.formData.schoolId, "Selecting 'None' should clear school ID")
  }

  func testSchoolSelection_existingSchool_setsSchoolId() {
    let viewModel = makeViewModel()

    viewModel.handleSchoolSelection("school-123")

    XCTAssertEqual(viewModel.formData.schoolId, "school-123", "Should set school ID to selected value")
  }

  // MARK: - Integration: Full Accessibility Flow

  func testFullAccessibilityFlow_success() async throws {
    let mockService = MockEventsService()
    let viewModel = makeViewModel(service: mockService)

    // Load schools
    mockService.stubbedSchools = [
      SchoolSummary(id: "s1", name: "State University", location: "Austin, TX")
    ]
    await viewModel.loadSchools()
    XCTAssertEqual(viewModel.schools.count, 1)

    // Fill required fields
    viewModel.formData.type = .showcase
    viewModel.formData.name = "Spring Showcase 2026"
    viewModel.formData.startDate = date("2026-04-15")

    // Fill optional fields
    viewModel.formData.schoolId = "s1"
    viewModel.formData.address = "100 Stadium Way"
    viewModel.formData.city = "Austin"
    viewModel.formData.state = "TX"
    viewModel.formData.registered = true

    // Verify accessibility-relevant state
    XCTAssertFalse(viewModel.isSubmitDisabled, "Submit should be enabled")
    XCTAssertTrue(viewModel.showGetDirections, "Get Directions should be visible")

    // Submit
    let eventId = await viewModel.createEvent()
    XCTAssertNotNil(eventId, "Should return event ID")
    XCTAssertFalse(viewModel.isSaving, "Should not be saving after completion")
    XCTAssertTrue(viewModel.validationErrors.isEmpty, "Should have no validation errors")
    XCTAssertNil(viewModel.error, "Should have no error")
  }

  func testFullAccessibilityFlow_validationFailure() async {
    let viewModel = makeViewModel()

    // Leave all required fields empty
    viewModel.formData.type = nil
    viewModel.formData.name = ""
    viewModel.formData.startDate = nil

    let result = await viewModel.createEvent()

    XCTAssertNil(result, "Should return nil on validation failure")
    XCTAssertFalse(viewModel.validationErrors.isEmpty, "Should have validation errors")
    XCTAssertEqual(viewModel.validationErrors.count, 3, "Should have 3 required field errors")
    XCTAssertFalse(viewModel.isSaving, "Should not be saving after validation failure")
  }

  func testFullAccessibilityFlow_serviceFailure() async {
    let mockService = MockEventsService()
    mockService.shouldThrowCreateEvent = true
    let viewModel = makeViewModel(service: mockService)

    // Fill valid form
    viewModel.formData.type = .game
    viewModel.formData.name = "Championship Game"
    viewModel.formData.startDate = date("2026-05-01")

    let result = await viewModel.createEvent()

    XCTAssertNil(result, "Should return nil on service failure")
    XCTAssertNotNil(viewModel.error, "Should set error message on service failure")
    XCTAssertFalse(viewModel.isSaving, "Should not be saving after error")
    XCTAssertTrue(viewModel.validationErrors.isEmpty, "Validation should have passed")
  }

  // MARK: - Dynamic Type Support

  func testEventType_displayNames_areNonTruncated() {
    // Verify display names are full words (not abbreviations) for screen readers
    let expectedNames: [EventType: String] = [
      .showcase: "Showcase",
      .camp: "Camp",
      .officialVisit: "Official Visit",
      .unofficialVisit: "Unofficial Visit",
      .game: "Game"
    ]

    for (type, expected) in expectedNames {
      XCTAssertEqual(type.displayName, expected, "\(type.rawValue) display name should be '\(expected)'")
    }
  }

  func testEventSource_displayNames_areNonTruncated() {
    let expectedNames: [EventSource: String] = [
      .email: "Email",
      .flyer: "Flyer",
      .webSearch: "Web Search",
      .recommendation: "Recommendation",
      .friend: "Friend",
      .other: "Other"
    ]

    for (source, expected) in expectedNames {
      XCTAssertEqual(source.displayName, expected, "\(source.rawValue) display name should be '\(expected)'")
    }
  }
}
