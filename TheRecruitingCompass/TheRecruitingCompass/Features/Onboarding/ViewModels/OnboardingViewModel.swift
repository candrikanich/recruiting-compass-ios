import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "OnboardingViewModel")

@Observable
@MainActor
final class OnboardingViewModel {
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

  var onComplete: (() -> Void)?

  private let onboardingService: any OnboardingManaging
  private let preferenceService: any PreferenceManaging
  private let authManager: any AuthManaging

  var positionsForSport: [String] {
    guard !primarySport.isEmpty,
          let positions = OnboardingConstants.sportPositions[primarySport] else {
      return []
    }
    return positions
  }

  init(
    onboardingService: (any OnboardingManaging)? = nil,
    preferenceService: (any PreferenceManaging)? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.onboardingService = onboardingService ?? OnboardingServiceImpl(supabaseManager: .shared)
    self.preferenceService = preferenceService ?? PreferenceServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
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
      isLoading = false
    } catch {
      logger.error("Failed to save onboarding step: \(error.localizedDescription)")
      errorMessage = error.localizedDescription
      isLoading = false
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

    do {
      let assessment = OnboardingAssessment.defaultForOnboarding
      let startingPhase = "freshman"

      try await onboardingService.completeOnboarding(
        userId: userId,
        assessment: assessment,
        startingPhase: startingPhase
      )

      // Mirrors web: onboarding completion does not create family; user creates from Family tab when inviting parent
      isLoading = false
      onComplete?()
    } catch {
      logger.error("Failed to complete onboarding: \(error.localizedDescription)")
      errorMessage = error.localizedDescription
      isLoading = false
    }
  }

  nonisolated deinit {}
}
