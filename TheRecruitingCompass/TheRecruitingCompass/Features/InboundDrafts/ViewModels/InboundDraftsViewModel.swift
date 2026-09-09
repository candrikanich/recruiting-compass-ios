import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "InboundDraftsViewModel")

@Observable
@MainActor
final class InboundDraftsViewModel {

  nonisolated deinit {}

  var drafts: [InboundEmailDraft] = []
  var isLoading = false
  var errorMessage: String?

  /// Draft the review sheet is open for — presenting the Log Interaction form
  /// prefilled from it (#113) instead of blind-accepting the parsed fields.
  var draftToReview: InboundEmailDraft?
  /// Draft ids currently mid-discard, so the card can disable its buttons.
  var pendingActionDraftIds: Set<String> = []

  var showErrorToast = false
  var toastMessage: String?

  private let apiService: any InboundDraftsAPIManaging
  private let familyManager: FamilyManager
  private let authManager: any AuthManaging

  init(
    apiService: (any InboundDraftsAPIManaging)? = nil,
    familyManager: FamilyManager? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.apiService = apiService ?? InboundDraftsAPIService()
    self.familyManager = familyManager ?? .shared
    self.authManager = authManager ?? AuthManager.shared
  }

  private var accessToken: String? { authManager.session?.accessToken }

  var familyUnitId: String? { familyManager.familyUnitId }
  var currentUserId: String? { authManager.user?.id }

  func loadDrafts() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      drafts = try await apiService.fetchPendingDrafts(accessToken: accessToken)
    } catch {
      logger.error("loadDrafts failed: \(error.localizedDescription)")
      errorMessage = String(localized: "Failed to load drafts. Please try again.")
    }
  }

  /// Opens the Log Interaction form prefilled from this draft for review —
  /// "Confirm" no longer blind-accepts the parser's output (#113).
  func reviewDraft(_ draft: InboundEmailDraft) {
    draftToReview = draft
  }

  /// Called once the review form successfully confirms the draft.
  func handleDraftConfirmed(_ id: String) {
    removeFromList(id)
  }

  func discard(_ draft: InboundEmailDraft) async {
    guard !pendingActionDraftIds.contains(draft.id) else { return }
    pendingActionDraftIds.insert(draft.id)
    defer { pendingActionDraftIds.remove(draft.id) }

    do {
      _ = try await apiService.discardDraft(id: draft.id, accessToken: accessToken)
      removeFromList(draft.id)
    } catch InboundDraftsAPIError.notFound {
      removeFromList(draft.id)
    } catch {
      logger.error("discard \(draft.id) failed: \(error.localizedDescription)")
      showToast(String(localized: "Failed to discard this draft. Please try again."))
    }
  }

  private func removeFromList(_ id: String) {
    drafts.removeAll { $0.id == id }
    if draftToReview?.id == id { draftToReview = nil }
  }

  private func showToast(_ message: String) {
    toastMessage = message
    showErrorToast = true
  }
}
