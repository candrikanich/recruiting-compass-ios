import Foundation
import Helpers
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "AccountProvisioning")

/// iOS's analogue to web's `ensureAccountProvisioned()` — called on every authenticated
/// session (explicit login, and the email-confirmation transition) to flush signup-time
/// `pending_*` auth metadata into real preferences. See
/// `planning/iOS_SPEC_preconfirm-onboarding-step1-2026-09-11.md`.
protocol AccountProvisioning: Sendable {
  func flushPendingOnboardingStep1() async
}

final class AccountProvisioningService: AccountProvisioning {
  private let supabaseManager: any SupabaseManaging
  private let preferenceService: any PreferenceManaging

  init(supabaseManager: any SupabaseManaging, preferenceService: any PreferenceManaging) {
    self.supabaseManager = supabaseManager
    self.preferenceService = preferenceService
  }

  /// Never throws out of the auth flow — sign-in/confirmation must succeed regardless of
  /// whether this flush succeeds. Idempotent: no-ops once the player has a primary sport.
  func flushPendingOnboardingStep1() async {
    do {
      guard let metadata = await supabaseManager.currentUserMetadata() else { return }
      guard let primarySport = Self.stringValue(metadata["pending_primary_sport"]), !primarySport.isEmpty,
            let graduationYearString = Self.stringValue(metadata["pending_graduation_year"]),
            let graduationYear = Int(graduationYearString) else {
        return
      }

      var details: PlayerDetails = try await preferenceService.fetchPreferences(category: .player) ?? .default
      guard (details.primarySport ?? "").isEmpty else {
        logger.debug("Skipping onboarding step 1 flush: player already has a primary sport")
        return
      }

      details.primarySport = primarySport
      details.graduationYear = graduationYear
      if let gender = Self.stringValue(metadata["pending_gender"]), !gender.isEmpty {
        details.gender = gender
      }
      _ = try await preferenceService.savePreferences(category: .player, data: details)

      if let zipCode = Self.stringValue(metadata["pending_zip_code"]), !zipCode.isEmpty {
        var location: HomeLocation = try await preferenceService.fetchPreferences(category: .location) ?? .default
        location.zip = zipCode
        _ = try await preferenceService.savePreferences(category: .location, data: location)
      }

      logger.info("Flushed pending onboarding step 1: sport=\(primarySport), gradYear=\(graduationYear)")
    } catch {
      logger.error("Failed to flush pending onboarding step 1: \(error.localizedDescription)")
    }
  }

  private static func stringValue(_ json: AnyJSON?) -> String? {
    guard case let value as String = json?.value else { return nil }
    return value
  }
}
