import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "ParentOnboardingWizard")

@Observable
@MainActor
final class ParentOnboardingWizardViewModel {

  nonisolated deinit {}
  enum Step: Int, CaseIterable {
    case playerDetails = 0
    case schoolsToExplore = 1
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
    to: .now
  ) ?? .now
  var hasConfirmedDateOfBirth = false

  var inviteEmail: String = ""

  /// Family code for "share your family code" (loaded lazily by InviteAthleteView).
  var familyCode: String?
  var isLoadingFamilyCode = false

  /// Step 2 — schools to explore (matches web's `pages/onboarding/parent.vue` Step 2).
  var recommendations: [SchoolRecommendation] = []
  var isLoadingRecommendations = false
  var schoolsAdded: Int = 0

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
  private let schoolsRepository: any SchoolsRepository
  private let recommendationService: any SchoolRecommendationManaging

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
    schoolsRepository: (any SchoolsRepository)? = nil,
    recommendationService: (any SchoolRecommendationManaging)? = nil
  ) {
    self.familyService = familyService ?? FamilyServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.schoolsRepository = schoolsRepository ?? SchoolsRepositoryImpl(supabaseManager: .shared)
    self.recommendationService = recommendationService ?? SchoolRecommendationServiceImpl(supabaseManager: .shared)
  }

  func nextStep() {
    guard currentStep.rawValue < Step.allCases.count - 1 else { return }
    currentStep = Step(rawValue: currentStep.rawValue + 1) ?? .schoolsToExplore
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

  /// Ensures a family exists and loads its code for the invite step (mirrors web: we have a family by the time we share or send invite).
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

  /// Step 1 -> Step 2 (matches web's `savePlayerDetails()`: persist, then advance and prefetch recommendations).
  func proceedFromPlayerDetails() async {
    guard isPlayerDetailsValid else { return }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let response = try await familyService.createFamily(role: .parent)
      try await familyService.savePlayerDetails(familyId: response.familyId, details: pendingPlayerDetails)
      familyCode = response.familyCode
      nextStep()
      await loadRecommendations()
    } catch {
      errorMessage = (error as? FamilyError)?.errorDescription ?? "Couldn't save your athlete's details. Please try again."
    }
  }

  // MARK: - Step 2 — Schools to Explore

  func loadRecommendations() async {
    guard let userId = authManager.user?.id else { return }

    isLoadingRecommendations = true
    defer { isLoadingRecommendations = false }

    do {
      recommendations = try await recommendationService.fetchRecommendations(athleteId: userId, limit: 8)
    } catch {
      logger.error("Failed to load recommendations: \(error.localizedDescription, privacy: .public)")
      recommendations = []
    }
  }

  func addSchool(_ recommendation: SchoolRecommendation) async -> Bool {
    guard let userId = authManager.user?.id else { return false }

    do {
      let familyUnit = try await familyService.getFamilyUnit(forUserId: userId)
      guard let familyUnitId = familyUnit?.id else {
        logger.warning("No family unit found; cannot create school")
        return false
      }

      let request = SchoolCreateRequest(
        userId: userId,
        familyUnitId: familyUnitId,
        name: recommendation.name,
        location: nil,
        city: nil,
        state: recommendation.state,
        division: recommendation.division,
        conference: recommendation.conference,
        website: nil,
        twitterHandle: nil,
        instagramHandle: nil,
        ncaaId: nil,
        notes: nil,
        status: "researching",
        academicInfo: nil,
        faviconUrl: nil
      )
      _ = try await schoolsRepository.createSchool(request: request)

      recommendations.removeAll { $0.catalogKey == recommendation.catalogKey }
      schoolsAdded += 1
      return true
    } catch {
      logger.error("Failed to add school: \(error.localizedDescription, privacy: .public)")
      errorMessage = "Couldn't add \(recommendation.name). Please try again."
      return false
    }
  }

  func dismissRecommendation(_ recommendation: SchoolRecommendation) async {
    guard let userId = authManager.user?.id else { return }

    recommendations.removeAll { $0.catalogKey == recommendation.catalogKey }

    do {
      try await recommendationService.dismissRecommendation(catalogKey: recommendation.catalogKey, athleteId: userId)
    } catch {
      logger.error("Failed to dismiss recommendation: \(error.localizedDescription, privacy: .public)")
    }
  }

  /// Matches web's `goToDashboard()` — always reachable, whether or not any school was added.
  func finishOnboarding() {
    didComplete = true
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
