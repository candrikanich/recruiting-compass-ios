import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "OffersListViewModel")

@Observable
@MainActor
final class OffersListViewModel {

  nonisolated deinit {}
  var allOffers: [Offer] = [] {
    didSet { recomputeFilteredOffers() }
  }
  var schools: [School] = [] {
    didSet { recomputeFilteredOffers() }
  }
  var isLoading = false
  var errorMessage: String?

  /// Drives the error alert directly, without a view-local Binding(get:set:) wrapper.
  var isShowingErrorAlert: Bool {
    get { errorMessage != nil }
    set { if !newValue { errorMessage = nil } }
  }
  var showAddForm = false
  var showComparison = false
  var selectedOfferIds: Set<String> = []
  var filters = OfferFilters() {
    didSet { recomputeFilteredOffers() }
  }
  var formState = NewOfferFormState()
  var isSubmitting = false
  var successMessage: String?
  var showSuccessToast = false
  var offerToDelete: Offer?
  var showDeleteConfirmation = false

  private let offersService: any OffersManaging
  private let familyManager: FamilyManager
  private let authManager: any AuthManaging

  // MARK: - Computed Properties

  /// Cached derived list — recomputed via `recomputeFilteredOffers()` whenever
  /// `allOffers`, `schools` (schoolSearch reads schoolName(for:)), or `filters`
  /// change. Do not compute this inline elsewhere; it would go stale silently.
  private(set) var filteredOffers: [Offer] = []

  private func recomputeFilteredOffers() {
    var result = allOffers

    if !filters.schoolSearch.isEmpty {
      let query = filters.schoolSearch
      result = result.filter { offer in
        schoolName(for: offer.schoolId).localizedStandardContains(query)
      }
    }

    if let status = filters.status {
      result = result.filter { $0.status == status }
    }

    if let offerType = filters.offerType {
      result = result.filter { $0.offerType == offerType }
    }

    filteredOffers = result.sorted { lhs, rhs in
      let ascending = filters.sortDirection == .ascending
      switch filters.sortBy {
      case .offerDate:
        return ascending ? lhs.displayOfferDate < rhs.displayOfferDate : lhs.displayOfferDate > rhs.displayOfferDate
      case .deadline:
        let lhsDays = lhs.daysUntilDeadline ?? Int.max
        let rhsDays = rhs.daysUntilDeadline ?? Int.max
        return ascending ? lhsDays < rhsDays : lhsDays > rhsDays
      case .percentage:
        let lhsPct = lhs.scholarshipPercentage ?? 0
        let rhsPct = rhs.scholarshipPercentage ?? 0
        return ascending ? lhsPct < rhsPct : lhsPct > rhsPct
      case .amount:
        let lhsAmt = lhs.scholarshipAmount ?? 0
        let rhsAmt = rhs.scholarshipAmount ?? 0
        return ascending ? lhsAmt < rhsAmt : lhsAmt > rhsAmt
      }
    }
  }

  var acceptedCount: Int {
    allOffers.count(where: { $0.status == .accepted })
  }

  var pendingCount: Int {
    allOffers.count(where: { $0.status == .pending })
  }

  var declinedCount: Int {
    allOffers.count(where: { $0.status == .declined })
  }

  var selectedOffers: [Offer] {
    allOffers.filter { selectedOfferIds.contains($0.id) }
  }

  var canCompare: Bool {
    selectedOfferIds.count >= 2
  }

  private var schoolNameMap: [String: String] {
    EntityNameLookup.schoolNameMap(from: schools)
  }

  // MARK: - Initialization

  private let cache: (any CacheManaging)?

  /// TTL for cached offers list (seconds).
  private static let offersListCacheTTL: TimeInterval = 60

  init(
    offersService: (any OffersManaging)? = nil,
    familyManager: FamilyManager? = nil,
    authManager: (any AuthManaging)? = nil,
    cache: (any CacheManaging)? = nil
  ) {
    self.offersService = offersService ?? OffersServiceImpl(supabaseManager: .shared)
    self.familyManager = familyManager ?? .shared
    self.authManager = authManager ?? AuthManager.shared
    self.cache = cache
  }

  /// The user whose offers we read/write. When a parent is viewing an athlete,
  /// offers belong to the athlete (mirrors web + DashboardViewModel); otherwise
  /// the logged-in user's own id.
  private var targetUserId: String? {
    familyManager.selectedAthlete?.userId ?? authManager.user?.id
  }

  /// Invalidates the cached offers list so the next `loadOffers()` refetches.
  /// Call after any mutation (create, delete). `OfferDetailViewModel`
  /// invalidates the same key (via `ListCacheKeys.offers`) after edit/delete.
  private func invalidateOffersListCache() async {
    guard let userId = targetUserId else { return }
    await (cache ?? InMemoryCache.shared).remove(forKey: ListCacheKeys.offers(userId: userId))
  }

  // MARK: - Data Loading

  func loadOffers() async {
    guard let userId = targetUserId else {
      logger.warning("No userId available")
      errorMessage = "Unable to load offers. Please try again."
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    let cacheKey = ListCacheKeys.offers(userId: userId)
    let cacheToUse = cache ?? InMemoryCache.shared

    do {
      if let familyUnitId = familyManager.familyUnitId {
        schools = try await offersService.fetchSchools(familyUnitId: familyUnitId)
      }

      if let cachedOffers = await cacheToUse.get([Offer].self, forKey: cacheKey) {
        allOffers = cachedOffers
        logger.info("Loaded \(self.allOffers.count) offers from cache")
      } else {
        let fetched = try await offersService.fetchOffers(userId: userId)
        allOffers = fetched
        await cacheToUse.set(fetched, forKey: cacheKey, ttlSeconds: Self.offersListCacheTTL)
        logger.info("Loaded \(self.allOffers.count) offers")
      }
    } catch {
      logger.error("Failed to load offers: \(error.localizedDescription)")
      errorMessage = "Failed to load offers. Please try again."
    }
  }

  // MARK: - Create

  func createOffer() async {
    guard formState.isValid else { return }
    guard let userId = targetUserId else { return }

    isSubmitting = true
    defer { isSubmitting = false }

    do {
      let request = OfferCreateRequest(userId: userId, form: formState)
      let newOffer = try await offersService.createOffer(request)
      allOffers.insert(newOffer, at: 0)
      formState.reset()
      showAddForm = false
      successMessage = "Offer logged successfully"
      showSuccessToast = true
      logger.info("Created offer: \(newOffer.id)")
      await invalidateOffersListCache()
    } catch {
      logger.error("Failed to create offer: \(error.localizedDescription)")
      errorMessage = "Failed to save offer. Please try again."
    }
  }

  // MARK: - Delete

  func confirmDelete(_ offer: Offer) {
    offerToDelete = offer
    showDeleteConfirmation = true
  }

  func deleteOffer() async {
    guard let offer = offerToDelete else { return }

    defer {
      offerToDelete = nil
      showDeleteConfirmation = false
    }

    do {
      try await offersService.deleteOffer(id: offer.id)
      allOffers.removeAll { $0.id == offer.id }
      selectedOfferIds.remove(offer.id)
      successMessage = "Offer deleted"
      showSuccessToast = true
      await invalidateOffersListCache()
      logger.info("Deleted offer: \(offer.id)")
    } catch {
      logger.error("Failed to delete offer: \(error.localizedDescription)")
      errorMessage = "Failed to delete offer. Please try again."
    }
  }

  // MARK: - Selection

  func toggleSelection(_ offerId: String) {
    if selectedOfferIds.contains(offerId) {
      selectedOfferIds.remove(offerId)
    } else {
      selectedOfferIds.insert(offerId)
    }
  }

  // MARK: - Filters

  func clearFilters() {
    filters = OfferFilters()
  }

  // MARK: - Helpers

  func schoolName(for schoolId: String) -> String {
    EntityNameLookup.schoolName(for: schoolId, in: schoolNameMap)
  }

}
