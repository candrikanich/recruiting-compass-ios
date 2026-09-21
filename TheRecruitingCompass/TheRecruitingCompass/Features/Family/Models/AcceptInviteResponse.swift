import Foundation

/// Response body from `POST /api/family/invite/:token/accept`.
struct AcceptInviteResponse: Codable, Sendable, Equatable {
  let success: Bool
  let familyUnitId: String
  let onboardingComplete: Bool
  let prefill: InvitePrefill?

  enum CodingKeys: String, CodingKey {
    case success
    case familyUnitId
    case onboardingComplete
    case prefill
  }
}
