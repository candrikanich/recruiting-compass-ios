import Foundation
@testable import TheRecruitingCompass

final class MockInboundDraftsAPIService: InboundDraftsAPIManaging, @unchecked Sendable {
  var draftsToReturn: [InboundEmailDraft] = []
  var addressToReturn = "family-a1b2c3d4@inbound.therecruitingcompass.com"
  var confirmResponse = InboundDraftConfirmResponse(ok: true, interactionId: "interaction-1")
  var discardResponse = InboundDraftDiscardResponse(ok: true)

  var errorToThrow: Error?

  var lastConfirmedDraftId: String?
  var lastConfirmedSchoolId: String?
  var lastDiscardedDraftId: String?
  var confirmCallCount = 0
  var discardCallCount = 0

  func fetchPendingDrafts(accessToken: String?) async throws -> [InboundEmailDraft] {
    if let errorToThrow { throw errorToThrow }
    return draftsToReturn
  }

  func confirmDraft(id: String, schoolId: String?, accessToken: String?) async throws -> InboundDraftConfirmResponse {
    confirmCallCount += 1
    lastConfirmedDraftId = id
    lastConfirmedSchoolId = schoolId
    if let errorToThrow { throw errorToThrow }
    return confirmResponse
  }

  func discardDraft(id: String, accessToken: String?) async throws -> InboundDraftDiscardResponse {
    discardCallCount += 1
    lastDiscardedDraftId = id
    if let errorToThrow { throw errorToThrow }
    return discardResponse
  }

  func fetchForwardingAddress(accessToken: String?) async throws -> String {
    if let errorToThrow { throw errorToThrow }
    return addressToReturn
  }
}
