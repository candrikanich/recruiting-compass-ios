import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "OfferDetailViewModel")

@Observable
@MainActor
final class OfferDetailViewModel {

  nonisolated deinit {}
  var offer: Offer?
  var school: School?
  var isLoading = false
  var errorMessage: String?
  var activeAlert: OfferAlertType?

  /// Drives the alert(_:isPresented:presenting:) directly, without a view-local Binding(get:set:) wrapper.
  var isShowingActiveAlert: Bool {
    get { activeAlert != nil }
    set { if !newValue { activeAlert = nil } }
  }
  var isEditing = false
  var editData = OfferEditData()
  var isUpdating = false
  var isDeleting = false

  private let offerId: String
  private let offersService: any OffersManaging
  private let authManager: any AuthManaging
  private let cache: (any CacheManaging)?

  private static let offerCacheTTL: TimeInterval = 60

  init(
    offerId: String,
    offersService: (any OffersManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    cache: (any CacheManaging)? = nil
  ) {
    self.offerId = offerId
    self.offersService = offersService ?? OffersServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.cache = cache
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

    let offerKey = "offer:\(offerId)"
    let cacheToUse = cache ?? InMemoryCache.shared

    if let cachedOffer = await cacheToUse.get(Offer.self, forKey: offerKey) {
      self.offer = cachedOffer
      if let cachedSchool = await cacheToUse.get(School.self, forKey: "school:\(cachedOffer.schoolId)") {
        self.school = cachedSchool
      } else {
        await loadSchoolForOffer(cachedOffer, cache: cacheToUse)
      }
      logger.info("Loaded offer from cache: \(cachedOffer.id)")
      return
    }

    do {
      let fetchedOffer = try await offersService.fetchOffer(id: offerId)
      self.offer = fetchedOffer
      await cacheToUse.set(fetchedOffer, forKey: offerKey, ttlSeconds: Self.offerCacheTTL)
      logger.info("Loaded offer: \(fetchedOffer.id)")

      await loadSchoolForOffer(fetchedOffer, cache: cacheToUse)
    } catch {
      errorMessage = "Failed to load offer details"
      logger.error("Failed to load offer: \(error.localizedDescription)")
    }
  }

  private func loadSchoolForOffer(_ offer: Offer, cache cacheToUse: any CacheManaging) async {
    let schoolKey = "school:\(offer.schoolId)"
    if let cachedSchool = await cacheToUse.get(School.self, forKey: schoolKey) {
      self.school = cachedSchool
      return
    }
    do {
      let fetchedSchool = try await offersService.fetchSchool(id: offer.schoolId)
      self.school = fetchedSchool
      await cacheToUse.set(fetchedSchool, forKey: schoolKey, ttlSeconds: Self.offerCacheTTL)
      logger.info("Loaded school: \(fetchedSchool.name)")
    } catch {
      // intentionally silent: the offer itself loaded fine; the view already
      // handles school == nil by falling back to the offer's stored school name.
      logger.warning("Failed to load school for offer: \(error.localizedDescription)")
    }
  }

  /// Invalidates this offer's cache plus OffersListViewModel's cached list
  /// (Phase 3.6), keyed by the offer's owning user id — matches
  /// OffersListViewModel.targetUserId for the athlete this offer belongs to.
  private func invalidateOfferCache() async {
    guard let offer else { return }
    let cacheToUse = cache ?? InMemoryCache.shared
    await cacheToUse.remove(forKey: "offer:\(offerId)")
    await cacheToUse.remove(forKey: "school:\(offer.schoolId)")
    await cacheToUse.remove(forKey: ListCacheKeys.offers(userId: offer.userId))
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
        await invalidateOfferCache()
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
        await invalidateOfferCache()
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
