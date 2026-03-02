import Foundation
import Observation

@Observable
@MainActor
final class ParentOnboardingWizardViewModel {
  enum Step: Int, CaseIterable {
    case playerDetails = 0
    case sendInvite = 1
  }

  var currentStep: Step = .playerDetails

  var playerFirstName: String = ""
  var playerLastName: String = ""
  var playerSport: String = ""
  var playerPosition: String = ""
  var playerGraduationYear: Int?
  /// Local-only COPPA gate; not persisted in PendingPlayerDetails.
  var playerDateOfBirth: Date = Calendar.current.date(
    byAdding: .year,
    value: -16,
    to: Date()
  ) ?? Date()
  var hasConfirmedDateOfBirth = false

  var inviteEmail: String = ""

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
    authManager: (any AuthManaging)? = nil
  ) {
    self.familyService = familyService ?? FamilyServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
  }

  func nextStep() {
    guard currentStep.rawValue < Step.allCases.count - 1 else { return }
    currentStep = Step(rawValue: currentStep.rawValue + 1) ?? .sendInvite
    errorMessage = nil
  }

  func previousStep() {
    guard currentStep.rawValue > 0 else { return }
    currentStep = Step(rawValue: currentStep.rawValue - 1) ?? .playerDetails
    errorMessage = nil
  }

  func onSportChange() {
    playerPosition = ""
  }

  func onDateOfBirthChange() {
    hasConfirmedDateOfBirth = true
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
      let first = playerFirstName.trimmingCharacters(in: .whitespaces)
      let lastTrimmed = playerLastName.trimmingCharacters(in: .whitespaces)
      let last = lastTrimmed.isEmpty ? "" : lastTrimmed
      let details = PendingPlayerDetails(
        firstName: first,
        lastName: last,
        sport: playerSport.isEmpty ? nil : playerSport,
        position: playerPosition.isEmpty ? nil : playerPosition,
        graduationYear: playerGraduationYear
      )
      try await familyService.sendEmailInvite(
        email: inviteEmail.trimmingCharacters(in: .whitespaces),
        role: "player",
        pendingPlayerDetails: details
      )
      successMessage = "Invite sent to \(inviteEmail.trimmingCharacters(in: .whitespaces))!"
      showSuccessToast = true
      didComplete = true
    } catch {
      errorMessage = (error as? FamilyError)?.errorDescription ?? "Failed to send invite. Please try again."
    }
  }

  nonisolated deinit {}
}
