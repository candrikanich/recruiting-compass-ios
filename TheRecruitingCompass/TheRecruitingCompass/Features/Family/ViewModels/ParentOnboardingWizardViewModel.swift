import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "ParentOnboardingWizard")

@Observable
@MainActor
final class ParentOnboardingWizardViewModel {

  nonisolated deinit {}

  var playerFirstName: String = ""
  var playerLastName: String = ""
  var playerSport: String = ""
  var playerPosition: String = ""
  var playerGraduationYear: Int?
  /// COPPA gate; persisted into PendingPlayerDetails.playerDob once confirmed so the invited
  /// player can be prefilled with it at signup.
  var playerDateOfBirth: Date = Calendar.current.date(
    byAdding: .year,
    value: -16,
    to: .now
  ) ?? .now
  var hasConfirmedDateOfBirth = false

  var inviteEmail: String = ""

  /// Family code for "share your family code" (loaded lazily by InviteAthleteView).
  var familyCode: String?
  var isLoadingFamilyCode = false

  var isLoading = false
  var errorMessage: String?
  var successMessage: String?
  var showSuccessToast = false
  var didComplete = false

  var sports: [String] { FamilyConstants.Sports.all }
  /// Positions limited to the selected sport (matches web); empty when no sport selected.
  var positionsForSport: [String] {
    guard !playerSport.isEmpty,
          let positions = OnboardingConstants.sportPositions[playerSport] else {
      return []
    }
    return positions
  }
  var graduationYears: [Int] {
    GradeLevelHelper.allowedGraduationYears
  }

  private let familyService: any FamilyManaging
  private let authManager: any AuthManaging
  private let onboardingService: any OnboardingManaging

  // No explicit timeZone: DatePicker's underlying Date represents local midnight for the
  // selected calendar day, so formatting must use the device's local timezone too (matching
  // COPPAHelper's parser) — forcing GMT here shifts the day for any device not on UTC.
  private var playerDateOfBirthString: String? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.string(from: playerDateOfBirth)
  }

  var isPlayerUnderAge: Bool {
    guard let dob = playerDateOfBirthString else { return false }
    return COPPAHelper.isUnderAge(dob)
  }

  var isPlayerDetailsValid: Bool {
    let first = playerFirstName.trimmingCharacters(in: .whitespaces)
    guard !first.isEmpty else { return false }
    guard hasConfirmedDateOfBirth,
          let dob = playerDateOfBirthString,
          !COPPAHelper.isUnderAge(dob) else {
      return false
    }
    return true
  }

  var isInviteStepValid: Bool {
    let email = inviteEmail.trimmingCharacters(in: .whitespaces)
    return email.contains("@") && email.contains(".")
  }

  init(
    familyService: (any FamilyManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    onboardingService: (any OnboardingManaging)? = nil
  ) {
    self.familyService = familyService ?? FamilyServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.onboardingService = onboardingService ?? OnboardingServiceImpl(supabaseManager: .shared)
  }

  func onSportChange() {
    playerPosition = ""
  }

  func onDateOfBirthChange() {
    hasConfirmedDateOfBirth = true
  }

  /// The family-required gate guarantees a family before onboarding, so this only reads it; it never creates one.
  func loadFamilyCode() async {
    isLoadingFamilyCode = true
    defer { isLoadingFamilyCode = false }
    do {
      familyCode = try await existingFamily().familyCode
    } catch {
      logger.error("loadFamilyCode failed: \(error.localizedDescription, privacy: .public) — full error: \(String(describing: error), privacy: .private)")
      familyCode = nil
      errorMessage = "Couldn't load your family code. Please try again."
    }
  }

  private func existingFamily() async throws -> FamilyUnit {
    guard let userId = authManager.user?.id,
          let family = try await familyService.getFamilyUnit(forUserId: userId) else {
      throw FamilyError.serverError("We couldn't find your family. Please sign out and back in.")
    }
    return family
  }

  private var pendingPlayerDetails: PendingPlayerDetails {
    let first = playerFirstName.trimmingCharacters(in: .whitespaces)
    let lastTrimmed = playerLastName.trimmingCharacters(in: .whitespaces)
    return PendingPlayerDetails(
      firstName: first,
      lastName: lastTrimmed,
      sport: playerSport.isEmpty ? nil : playerSport,
      position: playerPosition.isEmpty ? nil : playerPosition,
      graduationYear: playerGraduationYear,
      playerDob: hasConfirmedDateOfBirth ? playerDateOfBirthString : nil
    )
  }

  /// Single onboarding step (matches production web: create family, save player details, straight to
  /// dashboard — no invite step, no schools-recommendation step). Inviting the athlete happens later,
  /// from the dashboard's ParentOnboardingBanner (InviteAthleteView).
  func finishOnboarding() async {
    guard isPlayerDetailsValid else { return }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let family = try await existingFamily()
      try await familyService.savePlayerDetails(familyId: family.id, details: pendingPlayerDetails)
      familyCode = family.familyCode

      // Matches web's savePlayerDetails(): a failure here is logged but never blocks
      // reaching the dashboard — the shared onboarding_complete flag is best-effort.
      if let userId = authManager.user?.id {
        do {
          try await onboardingService.completeOnboarding(
            userId: userId,
            assessment: .defaultForOnboarding,
            startingPhase: OnboardingAssessment.startingPhase(for: .defaultForOnboarding, graduationYear: nil)
          )
        } catch {
          logger.error("completeOnboarding failed during parent onboarding: \(error.localizedDescription, privacy: .public)")
        }
      }

      didComplete = true
    } catch {
      logger.error("finishOnboarding failed: \(error.localizedDescription, privacy: .public) — full error: \(String(describing: error), privacy: .private)")
      errorMessage = (error as? FamilyError)?.errorDescription ?? "Couldn't save your athlete's details. Please try again."
    }
  }

  func sendInvite() async {
    guard isInviteStepValid else {
      errorMessage = "Please enter a valid email address"
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      // The standalone dashboard invite flow (InviteAthleteView) never collects
      // playerFirstName/playerLastName — those are only set by the onboarding wizard's
      // player-details step, and are already persisted via finishOnboarding()'s
      // savePlayerDetails() call. Sending pendingPlayerDetails here with an empty
      // first_name trips the server's Zod min(1) check (400: "Too small...").
      let hasPlayerDetails = !playerFirstName.trimmingCharacters(in: .whitespaces).isEmpty
      try await familyService.sendEmailInvite(
        email: inviteEmail.trimmingCharacters(in: .whitespaces),
        role: "player",
        pendingPlayerDetails: hasPlayerDetails ? pendingPlayerDetails : nil
      )
      successMessage = "Invite sent to \(inviteEmail.trimmingCharacters(in: .whitespaces))!"
      showSuccessToast = true
      didComplete = true
    } catch {
      logger.error("sendInvite failed: \(error.localizedDescription, privacy: .public)")
      errorMessage = (error as? FamilyError)?.errorDescription ?? "Failed to send invite. Please try again."
    }
  }

}
