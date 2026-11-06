import Foundation
import Observation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "MarketingConsentViewModel"
)

/// Drives the "Marketing Emails" toggle in notification settings (web #1066). The section stays
/// hidden until the server reports the user as eligible (parent, or player 18+).
@Observable
@MainActor
final class MarketingConsentViewModel {

  nonisolated deinit {}

  private(set) var isEligible = false
  private(set) var optIn = false
  private(set) var isSaving = false
  var errorMessage: String?

  private let service: any MarketingConsentManaging

  init(service: (any MarketingConsentManaging)? = nil) {
    self.service = service ?? MarketingConsentServiceImpl()
  }

  func load() async {
    do {
      let consent = try await service.fetchConsent()
      isEligible = consent.eligible
      optIn = consent.optIn
    } catch {
      // intentionally silent: an unreachable or not-yet-deployed endpoint just leaves the
      // section hidden — a toggle that can't save is worse than no toggle.
      logger.error("Marketing consent load failed: \(error.localizedDescription)")
      isEligible = false
    }
  }

  /// Flips the toggle immediately, then confirms with the server; a failed save restores the
  /// previous value so the UI never shows consent the server didn't record.
  func setOptIn(_ newValue: Bool) async {
    guard newValue != optIn, !isSaving else { return }
    let previous = optIn
    optIn = newValue
    isSaving = true
    errorMessage = nil
    defer { isSaving = false }

    do {
      let consent = try await service.updateConsent(optIn: newValue)
      isEligible = consent.eligible
      optIn = consent.optIn
    } catch MarketingConsentError.notEligible {
      optIn = previous
      isEligible = false
    } catch {
      logger.error("Marketing consent update failed: \(error.localizedDescription)")
      optIn = previous
      errorMessage = String(
        localized: "Couldn't update your marketing email preference. Please try again."
      )
    }
  }
}
