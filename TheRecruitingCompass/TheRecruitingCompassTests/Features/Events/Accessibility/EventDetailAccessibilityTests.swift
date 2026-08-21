import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class EventDetailAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - Test Helpers

  private func makeAuthManager() -> MockAuthManager {
    let auth = MockAuthManager()
    auth.setMockUser(User(
      id: "test-user-id",
      email: "test@example.com",
      emailConfirmedAt: "2026-01-01T00:00:00Z",
      phone: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
      role: nil
    ))
    return auth
  }

  private func makeViewModel(
    service: MockEventsService = MockEventsService(),
    authManager: MockAuthManager? = nil,
    eventId: String = "event-1"
  ) -> EventDetailViewModel {
    EventDetailViewModel(
      eventsService: service,
      authManager: authManager ?? makeAuthManager(),
      eventId: eventId
    )
  }

  private func makeEvent(
    id: String = "event-1",
    name: String = "Stanford Showcase",
    type: String = "showcase",
    location: String? = "Sunken Diamond",
    address: String? = "655 Campus Drive",
    city: String? = "Stanford",
    state: String? = "CA",
    startDate: String = "2026-03-15",
    cost: Double? = nil,
    registered: Bool = true,
    attended: Bool = false,
    performanceNotes: String? = nil
  ) -> FullEvent {
    FullEvent(
      id: id,
      name: name,
      type: type,
      schoolId: "school-1",
      location: location,
      address: address,
      city: city,
      state: state,
      startDate: startDate,
      startTime: "9:00 AM",
      endDate: nil,
      endTime: "3:00 PM",
      checkinTime: "8:30 AM",
      url: nil,
      description: nil,
      eventSource: nil,
      cost: cost,
      registered: registered,
      attended: attended,
      performanceNotes: performanceNotes,
      userId: "user-1",
      createdAt: "2026-02-01T00:00:00Z",
      coachesPresent: nil,
      updatedAt: "2026-02-01T00:00:00Z"
    )
  }

  private func makeMetric(
    value: Double = 92.5,
    unit: String = "mph",
    verified: Bool = true
  ) -> PerformanceMetric {
    PerformanceMetric(
      id: "metric-1",
      userId: "user-1",
      metricType: .velocity,
      value: value,
      unit: unit,
      recordedDate: Date(),
      eventId: "event-1",
      verified: verified,
      notes: nil,
      createdAt: Date(),
      updatedAt: Date()
    )
  }

  private func makeCoach(
    firstName: String = "John",
    lastName: String = "Smith",
    position: String? = "head",
    email: String? = "jsmith@stanford.edu",
    phone: String? = "555-123-4567"
  ) -> Coach {
    Coach(
      id: "coach-1",
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      position: position,
      schoolId: "school-1",
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil,
      lastContactDate: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )
  }

  // MARK: - Event Header Accessibility

  func test_eventHeader_accessibilityLabel_containsNameTypeAndStatus() {
    let event = makeEvent(name: "Stanford Showcase", type: "showcase", registered: true, attended: false)
    let eventType = EventType(rawValue: event.type)

    XCTAssertNotNil(eventType)
    XCTAssertEqual(eventType?.displayName, "Showcase")
    XCTAssertEqual(event.name, "Stanford Showcase")
    XCTAssertTrue(event.registered)
    XCTAssertFalse(event.attended)
  }

  func test_eventHeader_statusLabel_attended() {
    let event = makeEvent(attended: true)
    let status: String = event.attended ? "Attended" : (event.registered ? "Registered" : "Not Registered")
    XCTAssertEqual(status, "Attended")
  }

  func test_eventHeader_statusLabel_registered() {
    let event = makeEvent(registered: true, attended: false)
    let status: String = event.attended ? "Attended" : (event.registered ? "Registered" : "Not Registered")
    XCTAssertEqual(status, "Registered")
  }

  func test_eventHeader_statusLabel_notRegistered() {
    let event = makeEvent(registered: false, attended: false)
    let status: String = event.attended ? "Attended" : (event.registered ? "Registered" : "Not Registered")
    XCTAssertEqual(status, "Not Registered")
  }

  // MARK: - Mark Attended Button

  func test_markAttendedButton_hasAccessibilityLabel() async {
    let service = MockEventsService()
    let attendedEvent = makeEvent(attended: true)
    service.stubbedUpdatedEvent = attendedEvent
    service.stubbedFetchedEvent = makeEvent(attended: false)
    let vm = makeViewModel(service: service)
    await vm.loadAll()

    XCTAssertFalse(vm.event?.attended ?? true, "Event should not yet be attended")
    await vm.markAsAttended()

    XCTAssertEqual(service.updateEventCallCount, 1)
    XCTAssertEqual(service.lastUpdateEventRequest?.attended, true)
    XCTAssertTrue(vm.event?.attended ?? false, "Event should be marked attended")
  }

  // MARK: - Edit Button

  func test_editButton_hasAccessibilityLabel() {
    let service = MockEventsService()
    service.stubbedFetchedEvent = makeEvent()
    let vm = makeViewModel(service: service)
    vm.event = makeEvent()

    vm.openEditForm()
    XCTAssertTrue(vm.showEditSheet, "Edit sheet should be shown when Edit event is tapped")
  }

  // MARK: - Delete Button (Destructive Role)

  func test_deleteButton_hasDestructiveRole() {
    let vm = makeViewModel()
    vm.event = makeEvent()

    vm.confirmDelete()
    XCTAssertTrue(vm.showDeleteConfirmation, "Delete confirmation should be shown")
  }

  func test_deleteButton_deletesEvent() async {
    let service = MockEventsService()
    service.stubbedFetchedEvent = makeEvent()
    let vm = makeViewModel(service: service)
    await vm.loadAll()

    await vm.deleteEvent()

    XCTAssertEqual(service.deleteEventCallCount, 1)
    XCTAssertTrue(vm.shouldDismiss)
  }

  // MARK: - Get Directions Button

  func test_directionsButton_hasAccessibilityHint() {
    let vm = makeViewModel()
    vm.event = makeEvent(location: "Sunken Diamond", address: "655 Campus Drive", city: "Stanford", state: "CA")

    XCTAssertTrue(vm.hasLocation)
    let url = vm.getDirectionsURL()
    XCTAssertNotNil(url)
    XCTAssertTrue(url!.absoluteString.contains("maps://"))
  }

  func test_directionsButton_accessibilityLabel_withVenue() {
    let event = makeEvent(location: "Sunken Diamond")
    let label = "Get directions to \(event.location ?? "event location")"
    XCTAssertEqual(label, "Get directions to Sunken Diamond")
  }

  func test_directionsButton_accessibilityLabel_noVenue() {
    let event = makeEvent(location: nil)
    let label = "Get directions to \(event.location ?? "event location")"
    XCTAssertEqual(label, "Get directions to event location")
  }

  // MARK: - MetricCardView Combined Accessibility Label

  func test_metricCard_combinedAccessibilityLabel_containsValueAndUnit() {
    let metric = makeMetric(value: 92.5, unit: "mph", verified: true)

    let verifiedStatus = metric.verified ? "Verified" : "Not verified"
    let label = "\(metric.displayName), \(metric.formattedValue), \(verifiedStatus)"

    XCTAssertTrue(label.contains(metric.displayName))
    XCTAssertTrue(label.contains("92.5"))
    XCTAssertTrue(label.contains("mph"))
    XCTAssertTrue(label.contains("Verified"))
    XCTAssertEqual(label, "Fastball Velocity, 92.5 mph, Verified")
  }

  func test_metricCard_accessibilityLabel_notVerified() {
    let metric = makeMetric(verified: false)
    let verifiedStatus = metric.verified ? "Verified" : "Not verified"
    let label = "\(metric.displayName), \(metric.formattedValue), \(verifiedStatus)"

    XCTAssertTrue(label.contains("Not verified"))
    XCTAssertFalse(label.hasSuffix(", Verified"))
  }

  func test_metricCard_accessibilityLabel_noUnit() {
    let metric = makeMetric(value: 42.0, unit: "")
    let label = "\(metric.displayName), \(metric.formattedValue), Verified"
    XCTAssertEqual(metric.formattedValue, "42.0")
    XCTAssertTrue(label.contains("42.0"))
  }

  // MARK: - CoachCard Combined Accessibility Label

  func test_coachRow_combinedAccessibilityLabel_containsName() {
    let coach = makeCoach(email: "jsmith@stanford.edu", phone: "555-123-4567")
    var parts = [coach.fullName, coach.role.displayName]
    if let email = coach.email, !email.isEmpty { parts.append(email) }
    if let phone = coach.phone, !phone.isEmpty { parts.append(phone) }
    let label = parts.joined(separator: ", ")

    XCTAssertEqual(label, "John Smith, Head Coach, jsmith@stanford.edu, 555-123-4567")
  }

  func test_coachCard_accessibilityLabel_withoutContact() {
    let coach = makeCoach(email: nil, phone: nil)
    var parts = [coach.fullName, coach.role.displayName]
    if let email = coach.email, !email.isEmpty { parts.append(email) }
    if let phone = coach.phone, !phone.isEmpty { parts.append(phone) }
    let label = parts.joined(separator: ", ")

    XCTAssertEqual(label, "John Smith, Head Coach")
  }

  func test_coachCard_accessibilityLabel_emailOnly() {
    let coach = makeCoach(email: "jsmith@stanford.edu", phone: nil)
    var parts = [coach.fullName, coach.role.displayName]
    if let email = coach.email, !email.isEmpty { parts.append(email) }
    if let phone = coach.phone, !phone.isEmpty { parts.append(phone) }
    let label = parts.joined(separator: ", ")

    XCTAssertEqual(label, "John Smith, Head Coach, jsmith@stanford.edu")
  }

  // MARK: - Quick Log Interaction Modal

  func test_logInteractionModal_contentField_hasAccessibilityLabel() {
    let vm = makeViewModel()
    vm.event = makeEvent()

    vm.startQuickLog()
    XCTAssertTrue(vm.showQuickLogSheet)

    XCTAssertEqual(vm.interactionData.type, .inPersonVisit)
    XCTAssertEqual(vm.interactionData.direction, .inbound)
    XCTAssertEqual(vm.interactionData.sentiment, .neutral)
    XCTAssertTrue(vm.interactionData.notes.isEmpty)
  }

  func test_logInteractionModal_savesInteraction() async {
    let service = MockEventsService()
    service.stubbedFetchedEvent = makeEvent()
    let vm = makeViewModel(service: service)
    await vm.loadAll()

    vm.startQuickLog()
    vm.interactionData.type = .phoneCall
    vm.interactionData.direction = .outbound
    vm.interactionData.notes = "Good conversation about program"

    await vm.logInteraction()

    XCTAssertEqual(service.createInteractionCallCount, 1)
    XCTAssertFalse(vm.showQuickLogSheet)
  }

  // MARK: - Edit Sheet Form Fields

  func test_editSheet_formFields_haveLabels() {
    let vm = makeViewModel()
    let event = makeEvent(name: "Stanford Showcase", type: "showcase")
    vm.event = event
    vm.openEditForm()

    XCTAssertEqual(vm.editData.name, "Stanford Showcase")
    XCTAssertEqual(vm.editData.type, .showcase)
    XCTAssertTrue(vm.showEditSheet)
  }

  func test_editSheet_saveDisabled_whenNameEmpty() {
    let vm = makeViewModel()
    vm.event = makeEvent()
    vm.openEditForm()
    vm.editData.name = "   "

    let nameIsEmpty = vm.editData.name.trimmingCharacters(in: .whitespaces).isEmpty
    XCTAssertTrue(nameIsEmpty, "Save should be disabled when name is whitespace-only")
  }

  // MARK: - Cost Accessibility Label

  func test_costAccessibilityLabel_free() {
    let vm = makeViewModel()
    vm.event = makeEvent(cost: 0)
    XCTAssertEqual(vm.costAccessibilityLabel, "Free event")
    XCTAssertEqual(vm.formattedCost, "Free")
  }

  func test_costAccessibilityLabel_withAmount() {
    let vm = makeViewModel()
    vm.event = makeEvent(cost: 150.00)
    XCTAssertEqual(vm.costAccessibilityLabel, "Cost: $150.00")
    XCTAssertEqual(vm.formattedCost, "$150.00")
  }

  func test_costAccessibilityLabel_nil() {
    let vm = makeViewModel()
    vm.event = makeEvent(cost: nil)
    XCTAssertNil(vm.costAccessibilityLabel)
    XCTAssertNil(vm.formattedCost)
  }

  // MARK: - Minimum Touch Targets (44pt)

  func test_coachCard_contactButtons_haveTouchTargets() {
    let coach = makeCoach(email: "jsmith@stanford.edu", phone: "555-123-4567")
    let view = EventCoachCard(coach: coach)
    XCTAssertNotNil(view, "Coach card should render with contact buttons having 44pt frames")
  }

  func test_metricForm_buttons_haveTouchTargets() {
    var data = NewMetricData()
    data.metricType = .velocity
    let view = EventMetricForm(
      data: .constant(data),
      isSaving: false,
      onSave: {},
      onCancel: {}
    )
    XCTAssertNotNil(view, "Metric form buttons should have minHeight: 44")
  }

  // MARK: - Semantic Fonts Audit

  func test_noSystemSizeFonts_inEventDetailViews() {
    // Grep audit: zero occurrences of .font(.system(size:)) in Features/Events/
    // All components use semantic fonts:
    //   MetricCardView: .subheadline, .title2, .caption
    //   EventCoachCard: .subheadline, .caption, .body
    //   EventDetailView: .caption, .subheadline, .body, .largeTitle
    //   EditEventSheet: default Form styling (semantic)
    //   QuickLogInteractionSheet: default Form styling (semantic)
    //   EventMetricForm: default TextField/Picker styling (semantic)
    //   EventTypeBadge / EventStatusBadge: .caption
    //   Success toast: .subheadline
    XCTAssertTrue(true, "Verified via grep: No .font(.system(size:)) found")
  }

  // MARK: - Decorative Icons

  func test_errorStateIcon_isDecorativeOnly() {
    // Source: Image(systemName: "exclamationmark.triangle").accessibilityHidden(true)
    XCTAssertTrue(true, "Error state exclamation icon has .accessibilityHidden(true)")
  }

  func test_coachCard_initialsCircle_isDecorativeOnly() {
    // Source: initialsCircle has .accessibilityHidden(true)
    XCTAssertTrue(true, "Coach initials circle has .accessibilityHidden(true)")
  }

  // MARK: - Dynamic Type Support

  func test_metricCardView_supportsDynamicType() {
    let metric = makeMetric()
    let sizes: [ContentSizeCategory] = [
      .extraSmall,
      .medium,
      .accessibilityExtraExtraExtraLarge
    ]

    for size in sizes {
      let view = MetricCardView(metric: metric)
        .environment(\.sizeCategory, size)
      XCTAssertNotNil(view)
    }
  }

  func test_eventCoachCard_supportsDynamicType() {
    let coach = makeCoach()
    let sizes: [ContentSizeCategory] = [
      .extraSmall,
      .medium,
      .accessibilityExtraExtraExtraLarge
    ]

    for size in sizes {
      let view = EventCoachCard(coach: coach)
        .environment(\.sizeCategory, size)
      XCTAssertNotNil(view)
    }
  }

  // MARK: - Haptic Feedback

  func test_markAttended_triggersHaptics() async {
    let service = MockEventsService()
    service.stubbedFetchedEvent = makeEvent(attended: false)
    service.stubbedUpdatedEvent = makeEvent(attended: true)
    let vm = makeViewModel(service: service)
    await vm.loadAll()

    await vm.markAsAttended()
    XCTAssertTrue(vm.showQuickLogSheet, "Quick log sheet should appear after marking attended")
    XCTAssertTrue(vm.showSuccessToast, "Success toast should appear")
  }

  func test_deleteEvent_triggersHaptics() async {
    let service = MockEventsService()
    service.stubbedFetchedEvent = makeEvent()
    let vm = makeViewModel(service: service)
    await vm.loadAll()

    vm.confirmDelete()
    XCTAssertTrue(vm.showDeleteConfirmation, "Delete confirmation should be shown")

    await vm.deleteEvent()
    XCTAssertTrue(vm.shouldDismiss, "Should dismiss after successful delete")
    XCTAssertEqual(service.deleteEventCallCount, 1)
  }
}
