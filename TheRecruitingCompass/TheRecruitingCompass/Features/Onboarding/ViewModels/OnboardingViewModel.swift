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
  var zipCode: String = ""
  var gpa: Double?
  var satScore: Int?
  var actScore: Int?

  var isLoading = false
  var errorMessage: String?
  var zipCodeError: String?
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

  func loadExistingData() async {
    guard let existing: PlayerDetails = try? await preferenceService.fetchPreferences(category: .player) else { return }
    if let year = existing.graduationYear { graduationYear = year }
    if let sport = existing.primarySport, !sport.isEmpty { primarySport = sport }
    if let position = existing.primaryPosition, !position.isEmpty { primaryPosition = position }
    logger.debug("Pre-filled onboarding from existing player preferences")
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

  func validateStep() -> Bool {
    zipCodeError = nil

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
        details.primaryPosition = primaryPosition.isEmpty ? nil : primaryPosition
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
