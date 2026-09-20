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
  /// whether this flush succeeds. Idempotent: no-ops once the player has a primary sport /
  /// graduation year, respectively. Sport and grad year flush independently — a parent-invite
  /// signup may only carry one of the two (unlike self-signup step 1, which always collects
  /// both together), and dropping the one it does have re-prompts the player for it.
  func flushPendingOnboardingStep1() async {
    do {
      guard let metadata = await supabaseManager.currentUserMetadata() else { return }
      let pendingSport = Self.stringValue(metadata["pending_primary_sport"]).flatMap { $0.isEmpty ? nil : $0 }
      let pendingGraduationYear = Self.stringValue(metadata["pending_graduation_year"]).flatMap(Int.init)
      guard pendingSport != nil || pendingGraduationYear != nil else { return }

      var details: PlayerDetails = try await preferenceService.fetchPreferences(category: .player) ?? .default
      var didChange = false

      if let pendingSport, (details.primarySport ?? "").isEmpty {
        details.primarySport = pendingSport
        didChange = true
      }
      if let pendingGraduationYear, details.graduationYear == nil {
        details.graduationYear = pendingGraduationYear
        didChange = true
      }
      if let gender = Self.stringValue(metadata["pending_gender"]), !gender.isEmpty, (details.gender ?? "").isEmpty {
        details.gender = gender
        didChange = true
      }

      guard didChange else {
        logger.debug("Skipping onboarding step 1 flush: nothing pending is still unset")
        return
      }
      _ = try await preferenceService.savePreferences(category: .player, data: details)

      if let zipCode = Self.stringValue(metadata["pending_zip_code"]), !zipCode.isEmpty {
        var location: HomeLocation = try await preferenceService.fetchPreferences(category: .location) ?? .default
        location.zip = zipCode
        _ = try await preferenceService.savePreferences(category: .location, data: location)
      }

      logger.info("Flushed pending onboarding step 1: sport=\(pendingSport ?? "nil"), gradYear=\(pendingGraduationYear.map(String.init) ?? "nil")")
    } catch {
      logger.error("Failed to flush pending onboarding step 1: \(error.localizedDescription)")
    }
  }

  private static func stringValue(_ json: AnyJSON?) -> String? {
    guard case let value as String = json?.value else { return nil }
    return value
  }
}
