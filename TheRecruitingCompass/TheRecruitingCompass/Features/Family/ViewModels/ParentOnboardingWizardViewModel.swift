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
  /// Local-only COPPA gate; not persisted in PendingPlayerDetails.
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

  private var playerDateOfBirthString: String? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
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

  /// Ensures a family exists and loads its code for the invite sheet (mirrors web: we have a family by the time we share or send invite).
  func loadFamilyCode() async {
    isLoadingFamilyCode = true
    defer { isLoadingFamilyCode = false }
    do {
      let response = try await familyService.createFamily(role: .parent)
      familyCode = response.familyCode
    } catch {
      logger.error("loadFamilyCode failed: \(error.localizedDescription, privacy: .public) — full error: \(String(describing: error), privacy: .private)")
      familyCode = nil
      errorMessage = "Couldn't load your family code. Please try again."
    }
  }

  private var pendingPlayerDetails: PendingPlayerDetails {
    let first = playerFirstName.trimmingCharacters(in: .whitespaces)
    let lastTrimmed = playerLastName.trimmingCharacters(in: .whitespaces)
    return PendingPlayerDetails(
      firstName: first,
      lastName: lastTrimmed,
      sport: playerSport.isEmpty ? nil : playerSport,
      position: playerPosition.isEmpty ? nil : playerPosition,
      graduationYear: playerGraduationYear
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
      let response = try await familyService.createFamily(role: .parent)
      try await familyService.savePlayerDetails(familyId: response.familyId, details: pendingPlayerDetails)
      familyCode = response.familyCode

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
      try await familyService.sendEmailInvite(
        email: inviteEmail.trimmingCharacters(in: .whitespaces),
        role: "player",
        pendingPlayerDetails: pendingPlayerDetails
      )
      successMessage = "Invite sent to \(inviteEmail.trimmingCharacters(in: .whitespaces))!"
      showSuccessToast = true
      didComplete = true
    } catch {
      errorMessage = (error as? FamilyError)?.errorDescription ?? "Failed to send invite. Please try again."
    }
  }

}
