import Foundation
import Observation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "CreateEventViewModel"
)

@Observable
@MainActor
final class CreateEventViewModel {

  nonisolated deinit {}

  // MARK: - State

  var formData = CreateEventData()
  var schools: [SchoolSummary] = []
  var isLoading = false
  var isSaving = false
  var isSavingSchool = false
  var errorMessage: String?

  /// Drives the error alert directly, without a view-local Binding(get:set:) wrapper.
  var isShowingError: Bool {
    get { errorMessage != nil }
    set { if !newValue { errorMessage = nil } }
  }
  var validationErrors: [String: String] = [:]

  // Modal state
  var showOtherSchoolModal = false
  var showAddSchoolModal = false
  var otherSchoolName = ""
  var newSchoolName = ""
  var newSchoolLocation = ""

  // MARK: - Dependencies

  private let eventsService: any EventsManaging
  private let userId: String
  private let familyUnitId: String

  // MARK: - Computed Properties

  var isSubmitDisabled: Bool {
    isSaving || formData.type == nil || formData.name.trimmingCharacters(in: .whitespaces).isEmpty || formData.startDate == nil
  }

  var showGetDirections: Bool {
    !formData.address.isEmpty || !formData.city.isEmpty
  }

  // MARK: - Init

  nonisolated init(eventsService: any EventsManaging, userId: String, familyUnitId: String) {
    self.eventsService = eventsService
    self.userId = userId
    self.familyUnitId = familyUnitId
  }

  // MARK: - School Loading

  func loadSchools() async {
    logger.debug("Loading schools for event form")
    isLoading = true
    defer { isLoading = false }

    do {
      schools = try await eventsService.fetchSchools(familyUnitId: familyUnitId)
      logger.info("Loaded \(self.schools.count) schools")
    } catch {
      logger.error("Failed to load schools: \(error.localizedDescription)")
      self.errorMessage = String(localized: "Failed to load schools. Please try again.")
    }
  }

  // MARK: - School Selection

  func handleSchoolSelection(_ id: String?) {
    guard let id else {
      formData.schoolId = nil
      return
    }
    if id == "other" {
      formData.schoolId = nil
      showOtherSchoolModal = true
    } else if id == "add_new" {
      formData.schoolId = nil
      showAddSchoolModal = true
    } else if id == "none" {
      formData.schoolId = nil
    } else {
      formData.schoolId = id
    }
  }

  func handleOtherSchool() {
    let trimmed = otherSchoolName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    formData.location = trimmed
    showOtherSchoolModal = false
    otherSchoolName = ""
  }

  func saveNewSchool() async {
    let trimmedName = newSchoolName.trimmingCharacters(in: .whitespaces)
    guard !trimmedName.isEmpty else { return }

    logger.debug("Creating new school: \(trimmedName)")
    let location = newSchoolLocation.trimmingCharacters(in: .whitespaces)

    isSavingSchool = true
    defer { isSavingSchool = false }

    do {
      let school = try await eventsService.createSchool(
        name: trimmedName,
        location: location.isEmpty ? nil : location,
        userId: userId,
        familyUnitId: familyUnitId
      )
      schools.append(school)
      schools.sort { $0.name < $1.name }
      formData.schoolId = school.id
      showAddSchoolModal = false
      newSchoolName = ""
      newSchoolLocation = ""
      logger.info("New school created and selected: \(school.id)")
    } catch {
      logger.error("Failed to create school: \(error.localizedDescription)")
      self.errorMessage = String(localized: "Failed to add school. Please try again.")
    }
  }

  // MARK: - Auto-populate Helpers

  func onStartDateChanged() {
    if formData.endDate == nil {
      formData.endDate = formData.startDate
    }
  }

  func handleStartDateChanged(_ date: Date) {
    formData.startDate = date
    onStartDateChanged()
  }

  func onStartTimeChanged() {
    if formData.endTime == nil, let startTime = formData.startTime {
      formData.endTime = Calendar.current.date(byAdding: .hour, value: 1, to: startTime)
    }
  }

  func handleStartTimeChanged(_ time: Date) {
    formData.startTime = time
    onStartTimeChanged()
  }

  // MARK: - Validation

  func validateForm() -> Bool {
    validationErrors = [:]

    if formData.type == nil {
      validationErrors["type"] = String(localized: "Event type is required")
    }

    if formData.name.trimmingCharacters(in: .whitespaces).isEmpty {
      validationErrors["name"] = String(localized: "Event name is required")
    }

    if formData.startDate == nil {
      validationErrors["startDate"] = String(localized: "Start date is required")
    }

    if let endDate = formData.endDate, let startDate = formData.startDate,
       endDate < startDate {
      validationErrors["endDate"] = String(localized: "End date must be after start date")
    }

    if !formData.url.isEmpty {
      let trimmed = formData.url.trimmingCharacters(in: .whitespaces)
      let hasValidScheme = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
      if !hasValidScheme || URL(string: trimmed) == nil {
        validationErrors["url"] = String(localized: "Please enter a valid URL (e.g., https://...)")
      }
    }

    return validationErrors.isEmpty
  }

  // MARK: - Submit

  func createEvent() async -> String? {
    guard !isLoading, !isSaving else { return nil }
    guard validateForm() else { return nil }

    logger.debug("Creating event: \(self.formData.name)")
    isSaving = true
    errorMessage = nil
    defer { isSaving = false }

    let request = CreateEventRequest.from(formData: formData, userId: userId)
    do {
      let event = try await eventsService.createEvent(request)
      logger.info("Event created successfully: \(event.id)")

      // Invalidate EventsListViewModel's cached list (Phase 3.6) so the new
      // event appears immediately on next visit instead of waiting out the TTL.
      await InMemoryCache.shared.remove(forKey: ListCacheKeys.events(userId: userId))

      return event.id
    } catch {
      logger.error("Failed to create event: \(error.localizedDescription)")
      self.errorMessage = String(localized: "Failed to create event. Please check your connection and try again.")
      return nil
    }
  }

  // MARK: - Directions

  func getDirectionsURL() -> URL? {
    var parts: [String] = []
    if !formData.address.isEmpty { parts.append(formData.address) }
    if !formData.city.isEmpty { parts.append(formData.city) }
    if !formData.state.isEmpty { parts.append(formData.state) }

    let query = parts.joined(separator: ", ")
    guard !query.isEmpty,
          let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
      return nil
    }

    return URL(string: "maps://?q=\(encoded)")
  }

}
