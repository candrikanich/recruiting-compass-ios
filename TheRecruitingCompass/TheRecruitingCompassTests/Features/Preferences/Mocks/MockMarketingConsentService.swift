import Foundation
@testable import TheRecruitingCompass

final class MockMarketingConsentService: MarketingConsentManaging, @unchecked Sendable {
  var fetchResult: Result<MarketingConsent, Error> = .success(
    MarketingConsent(eligible: true, optIn: false, updatedAt: nil)
  )
  var updateResult: Result<MarketingConsent, Error>?
  private(set) var fetchCallCount = 0
  private(set) var updateCalls: [Bool] = []

  func fetchConsent() async throws -> MarketingConsent {
    fetchCallCount += 1
    return try fetchResult.get()
  }

  func updateConsent(optIn: Bool) async throws -> MarketingConsent {
    updateCalls.append(optIn)
    if let updateResult { return try updateResult.get() }
    return MarketingConsent(eligible: true, optIn: optIn, updatedAt: "2026-10-01T12:00:00Z")
  }
}
