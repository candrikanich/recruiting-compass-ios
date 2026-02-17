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

  // MARK: - State

  var formData = CreateEventData()
  var schools: [SchoolSummary] = []
  var isLoading = false
  var isSaving = false
  var error: String?
  var validationErrors: [String: String] = [:]

  // Modal state
  var showOtherSchoolModal = false
  var showAddSchoolModal = false
  var otherSchoolName = ""
  var newSchoolName = ""
  var newSchoolLocation = ""

  // MARK: - Dependencies

  private let eventsService: EventsManaging
  private let userId: String

  // MARK: - Computed Properties

  var isSubmitDisabled: Bool {
    isSaving || formData.type == nil || formData.name.trimmingCharacters(in: .whitespaces).isEmpty || formData.startDate.isEmpty
  }

  var showGetDirections: Bool {
    !formData.address.isEmpty || !formData.city.isEmpty
  }

  // MARK: - Init

  nonisolated init(eventsService: EventsManaging, userId: String) {
    self.eventsService = eventsService
    self.userId = userId
  }

  // MARK: - School Loading

  func loadSchools() async {
    logger.debug("Loading schools for event form")
    isLoading = true
    defer { isLoading = false }

    do {
      schools = try await eventsService.fetchSchools(userId: userId)
      logger.info("Loaded \(self.schools.count) schools")
    } catch {
      logger.error("Failed to load schools: \(error.localizedDescription)")
      self.error = "Failed to load schools. Please try again."
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

    do {
      let school = try await eventsService.createSchool(
        name: trimmedName,
        location: location.isEmpty ? nil : location,
        userId: userId
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
      self.error = "Failed to add school. Please try again."
    }
  }

  // MARK: - Auto-populate Helpers

  func onStartDateChanged() {
    if formData.endDate.isEmpty {
      formData.endDate = formData.startDate
    }
  }

  func handleStartDateChanged(_ date: String) {
    formData.startDate = date
    onStartDateChanged()
  }

  func onStartTimeChanged() {
    if formData.endTime.isEmpty, !formData.startTime.isEmpty {
      formData.endTime = addOneHour(to: formData.startTime)
    }
  }

  func handleStartTimeChanged(_ time: String) {
    formData.startTime = time
    onStartTimeChanged()
  }

  // MARK: - Validation

  func validateForm() -> Bool {
    validationErrors = [:]

    if formData.type == nil {
      validationErrors["type"] = "Event type is required"
    }

    if formData.name.trimmingCharacters(in: .whitespaces).isEmpty {
      validationErrors["name"] = "Event name is required"
    }

    if formData.startDate.isEmpty {
      validationErrors["startDate"] = "Start date is required"
    }

    if !formData.endDate.isEmpty, !formData.startDate.isEmpty,
       formData.endDate < formData.startDate {
      validationErrors["endDate"] = "End date must be after start date"
    }

    return validationErrors.isEmpty
  }

  // MARK: - Submit

  func createEvent() async -> String? {
    guard !isLoading, !isSaving else { return nil }
    guard validateForm() else { return nil }

    logger.debug("Creating event: \(self.formData.name)")
    isSaving = true
    error = nil
    defer { isSaving = false }

    let request = CreateEventRequest.from(formData: formData, userId: userId)
    do {
      let event = try await eventsService.createEvent(request)
      logger.info("Event created successfully: \(event.id)")
      return event.id
    } catch {
      logger.error("Failed to create event: \(error.localizedDescription)")
      self.error = "Failed to create event. Please check your connection and try again."
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

  // MARK: - Private Helpers

  private func addOneHour(to time: String) -> String {
    let components = time.split(separator: ":")
    guard components.count == 2,
          let hours = Int(components[0]),
          let minutes = Int(components[1]) else {
      return time
    }
    let endHour = (hours + 1) % 24
    return String(format: "%02d:%02d", endHour, minutes)
  }
}

enum EventError: LocalizedError {
  case validationFailed

  var errorDescription: String? {
    switch self {
    case .validationFailed:
      return "Please complete all required fields"
    }
  }
}
