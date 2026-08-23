import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "OnboardingViewModel")

@Observable
@MainActor
final class OnboardingViewModel {

  nonisolated deinit {}
  var currentStep = 1
  var graduationYear: Int?
  var primarySport: String = ""
  var primaryPosition: String = ""
  var gender: String?
  var zipCode: String = ""
  var gpa: Double?
  var satScore: Int?
  var actScore: Int?

  var isLoading = false
  var errorMessage: String?
  var zipCodeError: String?
  var sportError: String?
  var inviteEmail: String = ""
  var isInviteSent = false

  var onComplete: (() -> Void)?

  private let onboardingService: any OnboardingManaging
  private let preferenceService: any PreferenceManaging
  private let authManager: any AuthManaging
  private let familyService: any FamilyManaging

  var isEmailInviteValid: Bool {
    let trimmed = inviteEmail.trimmingCharacters(in: .whitespaces)
    return trimmed.contains("@") && trimmed.contains(".")
  }

  var positionsForSport: [String] {
    guard !primarySport.isEmpty,
          let positions = OnboardingConstants.sportPositions[primarySport] else {
      return []
    }
    return positions
  }

  var graduationYearDisplay: String {
    get { graduationYear.map { String($0) } ?? "" }
    set { graduationYear = Int(newValue) }
  }

  init(
    onComplete: (() -> Void)? = nil,
    onboardingService: (any OnboardingManaging)? = nil,
    preferenceService: (any PreferenceManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    familyService: (any FamilyManaging)? = nil
  ) {
    self.onComplete = onComplete
    self.onboardingService = onboardingService ?? OnboardingServiceImpl(supabaseManager: .shared)
    self.preferenceService = preferenceService ?? PreferenceServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.familyService = familyService ?? FamilyServiceImpl(supabaseManager: .shared)
  }

  /// Pre-fills onboarding from the athlete's canonical DB preferences (`player` + `location`).
  /// Fill-if-empty: a field the user has already set locally is never overwritten. This is the
  /// cross-platform prefill path — parent-entered data hydrated into canonical prefs (web) surfaces
  /// here on the player's iOS onboarding via a DB read, with no query-param/local-state transport.
  func loadExistingData() async {
    if let existing: PlayerDetails = try? await preferenceService.fetchPreferences(category: .player) {
      if graduationYear == nil, let year = existing.graduationYear { graduationYear = year }
      if primarySport.isEmpty, let sport = existing.primarySport, !sport.isEmpty { primarySport = sport }
      if primaryPosition.isEmpty, let position = existing.primaryPosition, !position.isEmpty {
        primaryPosition = CanonicalPositions.normalize(sport: existing.primarySport, position) ?? position
      }
      if gpa == nil { gpa = existing.gpa }
      if satScore == nil { satScore = existing.satScore }
      if actScore == nil { actScore = existing.actScore }
      if gender == nil, let existingGender = existing.gender, !existingGender.isEmpty { gender = existingGender }
    }
    if zipCode.isEmpty,
       let location: HomeLocation = try? await preferenceService.fetchPreferences(category: .location),
       let zip = location.zip, !zip.isEmpty {
      zipCode = zip
    }
    logger.debug("Pre-filled onboarding from existing canonical preferences")
  }

  func sendParentInvite() async {
    guard let userId = authManager.user?.id, isEmailInviteValid else { return }

    isLoading = true
    defer { isLoading = false }

    do {
      if try await familyService.getFamilyUnit(forUserId: userId) != nil {
        try await familyService.sendEmailInvite(email: inviteEmail, role: "parent", pendingPlayerDetails: nil)
        inviteEmail = ""
        isInviteSent = true
      } else {
        errorMessage = "Family not set up yet. Complete onboarding first."
      }
    } catch {
      errorMessage = "Failed to send invite. You can do this later from Family Management."
    }
  }

  /// True when Step 2's required primary sport is filled. Drives Next-button gating.
  var isSportStepValid: Bool {
    !primarySport.trimmingCharacters(in: .whitespaces).isEmpty
  }

  func validateStep() -> Bool {
    zipCodeError = nil
    sportError = nil

    if currentStep == 2 {
      if !isSportStepValid {
        sportError = "Primary sport is required"
        return false
      }
    }

    if currentStep == 3 {
      let trimmed = zipCode.trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty {
        zipCodeError = "Zip code is required"
        return false
      }
      if trimmed.count != 5 || !trimmed.allSatisfy(\.isNumber) {
        zipCodeError = "Please enter a valid 5-digit zip code"
        return false
      }
    }

    return true
  }

  func nextScreen() async {
    guard validateStep() else { return }

    if currentStep == OnboardingConstants.totalSteps {
      await completeOnboarding()
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      if currentStep == 2 {
        var details = PlayerDetails.default
        details.graduationYear = graduationYear
        details.primarySport = primarySport.isEmpty ? nil : primarySport
        // Seed the ordered positions[] from the onboarding pick so the array
        // (source of truth for coach-facing output) and primaryPosition agree
        // from account creation — prevents the two stores drifting apart.
        details.primaryPosition = primaryPosition.isEmpty ? nil : primaryPosition
        details.positions = primaryPosition.isEmpty ? nil : [primaryPosition]
        details.gender = gender
        _ = try await preferenceService.savePreferences(category: .player, data: details)
      } else if currentStep == 3 {
        var location = HomeLocation.default
        location.zip = zipCode.trimmingCharacters(in: .whitespaces)
        _ = try await preferenceService.savePreferences(category: .location, data: location)
      } else if currentStep == 4 {
        var details: PlayerDetails
        if let existing: PlayerDetails = try await preferenceService.fetchPreferences(category: .player) {
          details = existing
        } else {
          details = .default
        }
        details.gpa = gpa
        details.satScore = satScore
        details.actScore = actScore
        _ = try await preferenceService.savePreferences(category: .player, data: details)
      }

      currentStep += 1
    } catch {
      logger.error("Failed to save onboarding step: \(error.localizedDescription)")
      errorMessage = "Couldn't save this step. Please try again."
    }
  }

  func previousScreen() {
    if currentStep > 1 {
      currentStep -= 1
    }
  }

  func skipStep() async {
    guard currentStep < OnboardingConstants.totalSteps else { return }
    // Step 2 (primary sport) is required and cannot be skipped.
    guard currentStep != 2 else { return }

    isLoading = true
    errorMessage = nil
    currentStep += 1
    isLoading = false
  }

  func clearError() {
    errorMessage = nil
  }

  func onSportChange() {
    primaryPosition = ""
  }

  private func completeOnboarding() async {
    guard let userId = authManager.user?.id else {
      errorMessage = "User not authenticated"
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let assessment = OnboardingAssessment.defaultForOnboarding
      let startingPhase = "freshman"

      try await onboardingService.completeOnboarding(
        userId: userId,
        assessment: assessment,
        startingPhase: startingPhase
      )

      // Mirrors web: onboarding completion does not create family; user creates from Family tab when inviting parent
      onComplete?()
    } catch {
      logger.error("Failed to complete onboarding: \(error.localizedDescription)")
      errorMessage = "Couldn't finish setup. Please try again."
    }
  }

}
