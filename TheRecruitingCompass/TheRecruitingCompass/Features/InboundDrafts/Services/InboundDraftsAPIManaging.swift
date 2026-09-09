import Foundation

/// Reads/mutates `inbound_email_drafts` and the family's forwarding address via
/// the web app's Nitro endpoints (service-role-only tables, no direct client SELECT).
protocol InboundDraftsAPIManaging: Sendable {
  func fetchPendingDrafts(accessToken: String?) async throws -> [InboundEmailDraft]
  func confirmDraft(
    id: String,
    schoolId: String?,
    coachId: String??,
    type: String?,
    direction: String?,
    occurredAt: String?,
    subject: String?,
    content: String?,
    accessToken: String?
  ) async throws -> InboundDraftConfirmResponse
  func discardDraft(id: String, accessToken: String?) async throws -> InboundDraftDiscardResponse
  func fetchForwardingAddress(accessToken: String?) async throws -> String
}
