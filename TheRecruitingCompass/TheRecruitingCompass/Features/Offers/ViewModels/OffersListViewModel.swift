import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "OffersListViewModel")

@Observable
@MainActor
final class OffersListViewModel {
  var allOffers: [Offer] = []
  var schools: [School] = []
  var isLoading = false
  var errorMessage: String?
  var showAddForm = false
  var showComparison = false
  var selectedOfferIds: Set<String> = []
  var filters = OfferFilters()
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

  var filteredOffers: [Offer] {
    var result = allOffers

    if !filters.schoolSearch.isEmpty {
      let query = filters.schoolSearch.lowercased()
      result = result.filter { offer in
        let name = schoolName(for: offer.schoolId).lowercased()
        return name.contains(query)
      }
    }

    if let status = filters.status {
      result = result.filter { $0.status == status }
    }

    if let offerType = filters.offerType {
      result = result.filter { $0.offerType == offerType }
    }

    return result.sorted { lhs, rhs in
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
    allOffers.filter { $0.status == .accepted }.count
  }

  var pendingCount: Int {
    allOffers.filter { $0.status == .pending }.count
  }

  var declinedCount: Int {
    allOffers.filter { $0.status == .declined }.count
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

  init(
    offersService: (any OffersManaging)? = nil,
    familyManager: FamilyManager? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.offersService = offersService ?? OffersServiceImpl(supabaseManager: .shared)
    self.familyManager = familyManager ?? .shared
    self.authManager = authManager ?? AuthManager.shared
  }

  // MARK: - Data Loading

  func loadOffers() async {
    guard let userId = authManager.user?.id else {
      logger.warning("No userId available")
      errorMessage = "Unable to load offers. Please try again."
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      if let familyUnitId = familyManager.familyUnitId {
        schools = try await offersService.fetchSchools(familyUnitId: familyUnitId)
      }
      allOffers = try await offersService.fetchOffers(userId: userId)
      logger.info("Loaded \(self.allOffers.count) offers")
    } catch {
      logger.error("Failed to load offers: \(error.localizedDescription)")
      errorMessage = "Failed to load offers: \(error.localizedDescription)"
    }
  }

  // MARK: - Create

  func createOffer() async {
    guard formState.isValid else { return }
    guard let userId = authManager.user?.id else { return }

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
    } catch {
      logger.error("Failed to create offer: \(error.localizedDescription)")
      errorMessage = "Failed to save offer: \(error.localizedDescription)"
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
