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

  /// Draft ids currently mid-discard, so the card can disable its buttons.
  /// Confirm now happens via the edit form (`AddInteractionView`), not inline here.
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
  var userId: String? { authManager.session?.user.id }

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

  /// Confirms `draft` with the edited form values from `AddInteractionView`,
  /// passed as `submitOverride`. Returns the created interaction id so the form
  /// can treat it the same as a normal `createInteraction` result.
  func confirm(_ draft: InboundEmailDraft, with formState: InteractionFormState) async throws -> String? {
    let response = try await apiService.confirmDraft(
      id: draft.id,
      schoolId: formState.schoolId.isEmpty ? nil : formState.schoolId,
      coachId: .some(formState.coachId),
      type: formState.type?.rawValue,
      direction: formState.direction.rawValue,
      occurredAt: ISO8601DateFormatter().string(from: formState.occurredAt),
      subject: formState.subject.isEmpty ? nil : formState.subject,
      content: formState.content.isEmpty ? nil : formState.content,
      accessToken: accessToken
    )
    removeFromList(draft.id)
    return response.interactionId
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
  }

  private func showToast(_ message: String) {
    toastMessage = message
    showErrorToast = true
  }
}
