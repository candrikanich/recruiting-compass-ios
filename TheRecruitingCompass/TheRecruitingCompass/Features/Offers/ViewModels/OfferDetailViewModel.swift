import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "OfferDetailViewModel")

@Observable
@MainActor
final class OfferDetailViewModel {
  var offer: Offer?
  var school: School?
  var isLoading = false
  var errorMessage: String?
  var activeAlert: OfferAlertType?
  var isEditing = false
  var editData = OfferEditData()
  var isUpdating = false
  var isDeleting = false

  private let offerId: String
  private let offersService: any OffersManaging
  private let authManager: any AuthManaging

  init(
    offerId: String,
    offersService: (any OffersManaging)? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.offerId = offerId
    self.offersService = offersService ?? OffersServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
  }

  // MARK: - Helper Methods

  private func handleError(_ error: Error, userMessage: String) {
    ViewModelHelpers.handleError(error, userMessage: userMessage, logger: logger) {
      self.activeAlert = .error($0)
    }
  }

  // MARK: - Computed Properties

  var schoolName: String {
    school?.name ?? "Unknown School"
  }

  var formattedOfferDate: String {
    guard let offer else { return "" }
    return DateFormatting.mediumDate(offer.displayOfferDate)
  }

  var formattedDeadlineDate: String {
    guard let offer else { return "No deadline set" }
    guard let deadline = offer.displayDeadlineDate else { return "No deadline set" }
    return DateFormatting.mediumDate(deadline)
  }

  var deadlineDisplayText: String {
    guard let days = offer?.daysUntilDeadline else { return "---" }
    if days < 0 { return "\(abs(days))d overdue" }
    return "\(days)d"
  }

  // MARK: - Loading

  func loadOffer() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let fetchedOffer = try await offersService.fetchOffer(id: offerId)
      self.offer = fetchedOffer
      logger.info("Loaded offer: \(fetchedOffer.id)")

      do {
        let fetchedSchool = try await offersService.fetchSchool(id: fetchedOffer.schoolId)
        self.school = fetchedSchool
        logger.info("Loaded school: \(fetchedSchool.name)")
      } catch {
        logger.warning("Failed to load school for offer: \(error.localizedDescription)")
      }
    } catch {
      errorMessage = "Failed to load offer details"
      logger.error("Failed to load offer: \(error.localizedDescription)")
    }
  }

  // MARK: - Editing

  func startEditing() {
    guard let offer else { return }
    editData = OfferEditData(from: offer)
    isEditing = true
  }

  func cancelEditing() {
    isEditing = false
    editData = OfferEditData()
  }

  func saveChanges() async {
    await ViewModelHelpers.withLoading(set: { self.isUpdating = $0 }) {
      do {
        let request = OfferUpdateRequest(from: editData)
        let updated = try await offersService.updateOffer(id: offerId, data: request)
        self.offer = updated
        isEditing = false
        logger.info("Offer updated successfully")
      } catch {
        handleError(error, userMessage: "Failed to save changes")
      }
    }
  }

  // MARK: - Delete

  func confirmDelete() {
    activeAlert = .deleteConfirmation
  }

  func deleteOffer(onSuccess: @escaping () -> Void) async {
    await ViewModelHelpers.withLoading(set: { self.isDeleting = $0 }) {
      do {
        try await offersService.deleteOffer(id: offerId)
        logger.info("Offer deleted successfully")
        onSuccess()
      } catch {
        activeAlert = .deleteError("Failed to delete offer. Please try again.")
        logger.error("Failed to delete offer: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Scholarship Calculator

  func applyCalculatorValues(amount: Double, percentage: Int) {
    editData.scholarshipAmount = amount
    editData.scholarshipPercentage = percentage
    if !isEditing {
      startEditing()
    }
  }

}
