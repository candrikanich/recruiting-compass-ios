import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "InteractionsListViewModel")

@Observable
@MainActor
final class InteractionsListViewModel {

  nonisolated deinit {}
  var allInteractions: [Interaction] = [] {
    didSet { recomputeFilteredInteractions() }
  }
  var allSchools: [School] = []
  var allCoaches: [Coach] = []
  var isLoading = false
  var errorMessage: String?
  var filters = InteractionFilters() {
    didSet { recomputeFilteredInteractions() }
  }
  var showDeleteConfirmation = false
  var interactionToDelete: Interaction?
  var isDeleting = false
  var deleteErrorMessage: String?

  /// Drives the delete-error alert directly, without a view-local Binding(get:set:) wrapper.
  var isShowingDeleteError: Bool {
    get { deleteErrorMessage != nil }
    set { if !newValue { deleteErrorMessage = nil } }
  }
  var successMessage: String?
  var showSuccessToast = false

  let interactionsService: any InteractionsManaging
  private let familyManager: FamilyManager
  private let authManager: any AuthManaging

  // MARK: - Computed Properties

  /// Cached derived list — recomputed via `recomputeFilteredInteractions()` whenever
  /// `allInteractions` or `filters` change. Do not compute this inline elsewhere;
  /// it would go stale silently. Note: the time-period filter's cutoff is
  /// computed once per recompute (not live), same as the prior computed-property
  /// behavior — it only advances when a mutation triggers a recompute.
  private(set) var filteredInteractions: [Interaction] = []

  private func recomputeFilteredInteractions() {
    var result = allInteractions

    // 1. Text search (subject + content)
    if !filters.searchText.isEmpty {
      let query = filters.searchText
      result = result.filter { interaction in
        (interaction.subject?.localizedStandardContains(query) ?? false) ||
        (interaction.content?.localizedStandardContains(query) ?? false)
      }
    }

    // 2. Type filter
    if let type = filters.type {
      result = result.filter { $0.type == type }
    }

    // 3. Direction filter
    if let direction = filters.direction {
      result = result.filter { $0.direction == direction }
    }

    // 4. Sentiment filter
    if let sentiment = filters.sentiment {
      result = result.filter { $0.sentiment == sentiment }
    }

    // 5. Time period filter
    if let period = filters.timePeriod {
      let cutoff = Calendar.current.date(byAdding: .day, value: -period.rawValue, to: .now) ?? .now
      result = result.filter { $0.displayDate >= cutoff }
    }

    // 6. Logged By filter (parents only)
    if let userId = filters.loggedBy {
      result = result.filter { $0.loggedBy == userId }
    }

    // Sort by date descending (newest first)
    filteredInteractions = result.sorted { $0.displayDate > $1.displayDate }
  }

  var analytics: InteractionAnalytics {
    let filtered = filteredInteractions
    let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now

    return InteractionAnalytics(
      totalCount: filtered.count,
      outboundCount: filtered.count(where: { $0.direction == .outbound }),
      inboundCount: filtered.count(where: { $0.direction == .inbound }),
      thisWeekCount: filtered.count(where: { $0.displayDate >= weekAgo })
    )
  }

  var schoolNameMap: [String: String] {
    EntityNameLookup.schoolNameMap(from: allSchools)
  }

  var coachNameMap: [String: String] {
    EntityNameLookup.coachNameMap(from: allCoaches)
  }

  var activeFilterCount: Int {
    filters.activeFilterCount
  }

  var resultCount: Int {
    filteredInteractions.count
  }

  var isParent: Bool {
    familyManager.currentMember?.isParent ?? false
  }

  var isAthlete: Bool {
    familyManager.currentMember?.isAthlete ?? false
  }

  // MARK: - Initialization

  private let cache: (any CacheManaging)?

  /// TTL for cached interactions list (seconds).
  private static let interactionsListCacheTTL: TimeInterval = 60

  init(
    interactionsService: (any InteractionsManaging)? = nil,
    familyManager: FamilyManager? = nil,
    authManager: (any AuthManaging)? = nil,
    cache: (any CacheManaging)? = nil
  ) {
    self.interactionsService = interactionsService ?? InteractionsServiceImpl(supabaseManager: .shared)
    self.familyManager = familyManager ?? .shared
    self.authManager = authManager ?? AuthManager.shared
    self.cache = cache
  }

  /// Invalidates the cached interactions list for both fetch scopes so the
  /// next `loadInteractions()` refetches. `InteractionDetailViewModel` and
  /// `AddInteractionViewModel` invalidate the same keys after delete/create.
  private func invalidateInteractionsListCache() async {
    let cacheToUse = cache ?? InMemoryCache.shared
    if let familyUnitId = familyManager.currentMember?.familyUnitId {
      await cacheToUse.remove(forKey: ListCacheKeys.interactionsForFamily(familyUnitId: familyUnitId))
    }
    if let userId = authManager.user?.id {
      await cacheToUse.remove(forKey: ListCacheKeys.interactionsForAthlete(userId: userId))
    }
  }

  // MARK: - Data Loading

  func loadInteractions() async {
    guard let familyUnitId = familyManager.currentMember?.familyUnitId else {
      logger.warning("No familyUnitId available")
      errorMessage = "Unable to load interactions. Please try again."
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    let cacheToUse = cache ?? InMemoryCache.shared

    do {
      // Load schools and coaches for name lookup
      let schools = try await interactionsService.fetchSchools(familyUnitId: familyUnitId)
      allSchools = schools

      allCoaches = try await interactionsService.fetchCoaches(familyUnitId: familyUnitId)

      // Load interactions based on role
      if isAthlete, let userId = authManager.user?.id {
        // Athletes see only their own interactions
        let cacheKey = ListCacheKeys.interactionsForAthlete(userId: userId)
        if let cached = await cacheToUse.get([Interaction].self, forKey: cacheKey) {
          allInteractions = cached
          logger.info("Loaded \(self.allInteractions.count) interactions for athlete from cache")
        } else {
          let fetched = try await interactionsService.fetchInteractionsForUser(userId: userId)
          allInteractions = fetched
          await cacheToUse.set(fetched, forKey: cacheKey, ttlSeconds: Self.interactionsListCacheTTL)
          logger.info("Loaded \(self.allInteractions.count) interactions for athlete")
        }
      } else {
        // Parents see all family interactions
        let cacheKey = ListCacheKeys.interactionsForFamily(familyUnitId: familyUnitId)
        if let cached = await cacheToUse.get([Interaction].self, forKey: cacheKey) {
          allInteractions = cached
          logger.info("Loaded \(self.allInteractions.count) interactions for family from cache")
        } else {
          let fetched = try await interactionsService.fetchInteractions(familyUnitId: familyUnitId)
          allInteractions = fetched
          await cacheToUse.set(fetched, forKey: cacheKey, ttlSeconds: Self.interactionsListCacheTTL)
          logger.info("Loaded \(self.allInteractions.count) interactions for family")
        }
      }
    } catch {
      logger.error("Failed to load interactions: \(error.localizedDescription)")
      errorMessage = "Failed to load interactions. Please try again."
    }
  }

  // MARK: - Delete

  func confirmDelete(_ interaction: Interaction) {
    interactionToDelete = interaction
    showDeleteConfirmation = true
  }

  func deleteInteraction() async {
    guard let interaction = interactionToDelete else { return }
    let interactionSubject = interaction.subject ?? interaction.type.displayName

    isDeleting = true
    deleteErrorMessage = nil
    successMessage = nil
    defer {
      isDeleting = false
      interactionToDelete = nil
      showDeleteConfirmation = false
    }

    do {
      try await interactionsService.deleteInteraction(id: interaction.id)
      allInteractions.removeAll { $0.id == interaction.id }
      logger.info("Deleted interaction: \(interactionSubject)")
      successMessage = "Interaction deleted"
      showSuccessToast = true
      await invalidateInteractionsListCache()
    } catch {
      logger.warning("Simple delete failed, attempting cascade: \(error.localizedDescription)")
      do {
        let result = try await interactionsService.cascadeDeleteInteraction(id: interaction.id)
        allInteractions.removeAll { $0.id == interaction.id }
        logger.info("Cascade deleted interaction: \(interactionSubject)")

        // Build detailed success message
        let totalDeleted = result.deletedInteractions + result.deletedNotes
        if totalDeleted > 0 {
          successMessage = "Interaction and \(totalDeleted) related record\(totalDeleted == 1 ? "" : "s") deleted"
        } else {
          successMessage = "Interaction deleted"
        }
        showSuccessToast = true
        await invalidateInteractionsListCache()
      } catch {
        logger.error("Cascade delete failed: \(error.localizedDescription)")
        deleteErrorMessage = "Failed to delete interaction. Please try again."
      }
    }
  }

  // MARK: - Filters

  func clearFilters() {
    filters = InteractionFilters()
  }

  // MARK: - Helpers

  func schoolName(for schoolId: String?) -> String? {
    guard let schoolId else { return nil }
    return EntityNameLookup.schoolName(for: schoolId, in: schoolNameMap)
  }

  func coachName(for coachId: String?) -> String? {
    guard let coachId else { return nil }
    return EntityNameLookup.coachName(for: coachId, in: coachNameMap)
  }

}
