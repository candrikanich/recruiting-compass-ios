import Foundation
import Observation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "InboundDraftsViewModel")

@Observable
@MainActor
final class InboundDraftsViewModel {

  nonisolated deinit {}

  var drafts: [InboundEmailDraft] = []
  var schools: [School] = []
  var isLoading = false
  var errorMessage: String?

  /// School picked in each draft's inline picker, keyed by draft id — only
  /// relevant for drafts whose `matchedSchoolId` is nil.
  var pickedSchoolId: [String: String] = [:]
  /// Draft ids currently mid-confirm/discard, so the card can disable its buttons.
  var pendingActionDraftIds: Set<String> = []

  var showErrorToast = false
  var toastMessage: String?

  private let apiService: any InboundDraftsAPIManaging
  private let supabaseManager: SupabaseManager
  private let familyManager: FamilyManager
  private let authManager: any AuthManaging

  init(
    apiService: (any InboundDraftsAPIManaging)? = nil,
    supabaseManager: SupabaseManager = .shared,
    familyManager: FamilyManager? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.apiService = apiService ?? InboundDraftsAPIService()
    self.supabaseManager = supabaseManager
    self.familyManager = familyManager ?? .shared
    self.authManager = authManager ?? AuthManager.shared
  }

  private var accessToken: String? { authManager.session?.accessToken }

  func loadDrafts() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      async let draftsTask = apiService.fetchPendingDrafts(accessToken: accessToken)
      async let schoolsTask = loadSchools()
      drafts = try await draftsTask
      _ = await schoolsTask
    } catch {
      logger.error("loadDrafts failed: \(error.localizedDescription)")
      errorMessage = String(localized: "Failed to load drafts. Please try again.")
    }
  }

  /// Best-effort — an unmatched draft's picker just shows no options if this fails.
  private func loadSchools() async {
    guard let familyUnitId = familyManager.familyUnitId else { return }
    do {
      schools = try await FamilyScopedQueries.fetchSchools(from: supabaseManager.client, familyUnitId: familyUnitId, orderedByName: true)
    } catch {
      logger.error("loadSchools failed: \(error.localizedDescription)")
    }
  }

  /// Mirrors web's `:disabled="!draft.matched_school_id && !schoolIdByDraft[draft.id]"`.
  func canConfirm(_ draft: InboundEmailDraft) -> Bool {
    draft.matchedSchoolId != nil || pickedSchoolId[draft.id] != nil
  }

  func confirm(_ draft: InboundEmailDraft) async {
    guard !pendingActionDraftIds.contains(draft.id) else { return }
    pendingActionDraftIds.insert(draft.id)
    defer { pendingActionDraftIds.remove(draft.id) }

    do {
      _ = try await apiService.confirmDraft(
        id: draft.id,
        schoolId: draft.matchedSchoolId == nil ? pickedSchoolId[draft.id] : nil,
        accessToken: accessToken
      )
      removeFromList(draft.id)
    } catch InboundDraftsAPIError.notFound {
      // Draft no longer exists (already handled elsewhere) — treat as resolved.
      removeFromList(draft.id)
    } catch InboundDraftsAPIError.validation(let message) {
      logger.error("confirm \(draft.id) rejected: \(message)")
      showToast(message)
    } catch {
      logger.error("confirm \(draft.id) failed: \(error.localizedDescription)")
      showToast(String(localized: "Failed to confirm this draft. Please try again."))
    }
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
    pickedSchoolId[id] = nil
  }

  private func showToast(_ message: String) {
    toastMessage = message
    showErrorToast = true
  }
}
