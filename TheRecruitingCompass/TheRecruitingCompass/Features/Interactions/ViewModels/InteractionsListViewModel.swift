import Combine
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "InteractionsListViewModel")

@MainActor
final class InteractionsListViewModel: ObservableObject {
  @Published var allInteractions: [Interaction] = []
  @Published var allSchools: [School] = []
  @Published var allCoaches: [Coach] = []
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var filters = InteractionFilters()
  @Published var showDeleteConfirmation = false
  @Published var interactionToDelete: Interaction?
  @Published var isDeleting = false
  @Published var deleteErrorMessage: String?
  @Published var successMessage: String?
  @Published var showSuccessToast = false

  private let interactionsService: any InteractionsManaging
  private let familyManager: FamilyManager
  private let authManager: any AuthManaging

  // MARK: - Computed Properties

  var filteredInteractions: [Interaction] {
    var result = allInteractions

    // 1. Text search (subject + content)
    if !filters.searchText.isEmpty {
      let query = filters.searchText.lowercased()
      result = result.filter { interaction in
        (interaction.subject?.lowercased().contains(query) ?? false) ||
        (interaction.content?.lowercased().contains(query) ?? false)
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
      let cutoff = Calendar.current.date(byAdding: .day, value: -period.rawValue, to: Date()) ?? Date()
      result = result.filter { $0.displayDate >= cutoff }
    }

    // 6. Logged By filter (parents only)
    if let userId = filters.loggedBy {
      result = result.filter { $0.loggedBy == userId }
    }

    // Sort by date descending (newest first)
    return result.sorted { $0.displayDate > $1.displayDate }
  }

  var analytics: InteractionAnalytics {
    let filtered = filteredInteractions
    let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

    return InteractionAnalytics(
      totalCount: filtered.count,
      outboundCount: filtered.filter { $0.direction == .outbound }.count,
      inboundCount: filtered.filter { $0.direction == .inbound }.count,
      thisWeekCount: filtered.filter { $0.displayDate >= weekAgo }.count
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

  nonisolated init(
    interactionsService: any InteractionsManaging = InteractionsServiceImpl(supabaseManager: .shared),
    familyManager: FamilyManager = .shared,
    authManager: any AuthManaging = AuthManager.shared
  ) {
    self.interactionsService = interactionsService
    self.familyManager = familyManager
    self.authManager = authManager
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

    do {
      // Load schools and coaches for name lookup
      let schools = try await interactionsService.fetchSchools(familyUnitId: familyUnitId)
      allSchools = schools

      let schoolIds = schools.map(\.id)
      allCoaches = try await interactionsService.fetchCoaches(schoolIds: schoolIds)

      // Load interactions based on role
      if isAthlete, let userId = authManager.user?.id {
        // Athletes see only their own interactions
        allInteractions = try await interactionsService.fetchInteractionsForUser(userId: userId)
        logger.info("Loaded \(self.allInteractions.count) interactions for athlete")
      } else {
        // Parents see all family interactions
        allInteractions = try await interactionsService.fetchInteractions(familyUnitId: familyUnitId)
        logger.info("Loaded \(self.allInteractions.count) interactions for family")
      }
    } catch {
      logger.error("Failed to load interactions: \(error.localizedDescription)")
      errorMessage = "Failed to load interactions: \(error.localizedDescription)"
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
