import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "OnboardingV2ViewModel")

/// View model for the new 2-step onboarding flow. Step 1 collects sport, graduation year,
/// and optional zip code; Step 2 shows school recommendations. Saves player details via
/// the same preference service path as the legacy flow.
@Observable
@MainActor
final class OnboardingV2ViewModel {

  nonisolated deinit {}

  // MARK: - Step 1 fields

  var primarySport: String = ""
  var graduationYear: Int?
  var zipCode: String = ""

  // MARK: - Step 2 fields

  var recommendations: [SchoolRecommendation] = []
  var isLoadingRecommendations = false
  var schoolsAdded: Int = 0

  // MARK: - Shared state

  var isLoading = false
  var errorMessage: String?
  var sportSearchText: String = ""

  // MARK: - Derived

  var filteredSports: [String] {
    let trimmed = sportSearchText.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return OnboardingConstants.commonSports }
    return OnboardingConstants.commonSports.filter { $0.localizedCaseInsensitiveContains(trimmed) }
  }

  var graduationYearDisplay: String {
    get { graduationYear.map { String($0) } ?? "" }
    set { graduationYear = Int(newValue) }
  }

  var isStep1Valid: Bool {
    !primarySport.trimmingCharacters(in: .whitespaces).isEmpty && graduationYear != nil
  }

  var zipCodeError: String? {
    let trimmed = zipCode.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    if trimmed.count != 5 || !trimmed.allSatisfy(\.isNumber) {
      return "Please enter a valid 5-digit zip code"
    }
    return nil
  }

  /// Gender auto-derived from sport. Nil for neutral/co-ed sports (user may set manually elsewhere).
  var derivedGender: String? {
    SportGenderMap.gender(for: primarySport).genderRawValue
  }

  // MARK: - Dependencies

  private let onboardingService: any OnboardingManaging
  private let preferenceService: any PreferenceManaging
  private let authManager: any AuthManaging
  private let schoolsRepository: any SchoolsRepository
  private let recommendationService: any SchoolRecommendationManaging
  private let familyService: any FamilyManaging
  private let ncaaDatabase: any NcaaDatabaseManaging
  private let collegeScorecardService: any CollegeScorecardManaging
  private let faviconService: any SchoolFaviconManaging

  init(
    onboardingService: (any OnboardingManaging)? = nil,
    preferenceService: (any PreferenceManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    schoolsRepository: (any SchoolsRepository)? = nil,
    recommendationService: (any SchoolRecommendationManaging)? = nil,
    familyService: (any FamilyManaging)? = nil,
    ncaaDatabase: (any NcaaDatabaseManaging)? = nil,
    collegeScorecardService: (any CollegeScorecardManaging)? = nil,
    faviconService: (any SchoolFaviconManaging)? = nil
  ) {
    self.onboardingService = onboardingService ?? OnboardingServiceImpl(supabaseManager: .shared)
    self.preferenceService = preferenceService ?? PreferenceServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.schoolsRepository = schoolsRepository ?? SchoolsRepositoryImpl(supabaseManager: .shared)
    self.recommendationService = recommendationService ?? SchoolRecommendationServiceImpl(supabaseManager: .shared)
    self.familyService = familyService ?? FamilyServiceImpl(supabaseManager: .shared)
    self.ncaaDatabase = ncaaDatabase ?? NcaaDatabase.shared
    self.collegeScorecardService = collegeScorecardService ?? CollegeScorecardService()
    self.faviconService = faviconService ?? SchoolFaviconService()
  }

  // MARK: - Step 1

  /// Pre-fill from existing canonical preferences (parent may have entered data on web).
  ///
  /// Returns `false` only when the player-preferences fetch itself failed (network/server
  /// error) — distinct from a successful fetch that simply found nothing. The caller (the
  /// onboarding container, deciding whether to skip Step 1) must not treat those the same:
  /// silently defaulting a failed read to "no data" could route a player who already has
  /// real canonical sport/grad-year through the redundant Step 1, or worse, let them
  /// overwrite it. The location/zip fetch failing is lower-stakes (only affects zip
  /// pre-fill, not the step-skip decision) and stays best-effort.
  @discardableResult
  func loadExistingData() async -> Bool {
    var playerFetchSucceeded = true
    do {
      if let existing: PlayerDetails = try await preferenceService.fetchPreferences(category: .player) {
        if graduationYear == nil, let year = existing.graduationYear { graduationYear = year }
        if primarySport.isEmpty, let sport = existing.primarySport, !sport.isEmpty { primarySport = sport }
      }
    } catch {
      playerFetchSucceeded = false
      logger.error("Failed to load existing player preferences: \(error.localizedDescription)")
    }

    if zipCode.isEmpty,
       let location: HomeLocation = try? await preferenceService.fetchPreferences(category: .location),
       let zip = location.zip, !zip.isEmpty {
      zipCode = zip
    }
    logger.debug("Pre-filled onboarding v2 from existing preferences (playerFetchSucceeded: \(playerFetchSucceeded))")
    return playerFetchSucceeded
  }

  /// Saves Step 1 data (sport, graduation year, zip, auto-derived gender) to player preferences.
  func saveStep1() async -> Bool {
    guard isStep1Valid else { return false }

    // Validate zip if provided
    let trimmedZip = zipCode.trimmingCharacters(in: .whitespaces)
    if !trimmedZip.isEmpty && (trimmedZip.count != 5 || !trimmedZip.allSatisfy(\.isNumber)) {
      return false
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      // Save player details (fetch-then-merge to preserve existing fields)
      var details: PlayerDetails
      if let existing: PlayerDetails = try? await preferenceService.fetchPreferences(category: .player) {
        details = existing
      } else {
        details = .default
      }
      details.primarySport = primarySport
      details.graduationYear = graduationYear
      details.gender = derivedGender ?? details.gender
      _ = try await preferenceService.savePreferences(category: .player, data: details)

      // Save zip if provided
      if !trimmedZip.isEmpty {
        var location: HomeLocation
        if let existing: HomeLocation = try? await preferenceService.fetchPreferences(category: .location) {
          location = existing
        } else {
          location = .default
        }
        location.zip = trimmedZip
        _ = try await preferenceService.savePreferences(category: .location, data: location)
      }

      OnboardingAnalytics.step1Complete(sport: primarySport, gradYear: graduationYear ?? 0)
      logger.info("Onboarding v2 Step 1 saved: sport=\(self.primarySport), gradYear=\(self.graduationYear ?? 0)")
      return true
    } catch {
      logger.error("Failed to save Step 1: \(error.localizedDescription)")
      errorMessage = "Couldn't save your info. Please try again."
      return false
    }
  }

  // MARK: - Step 2

  func loadRecommendations() async {
    guard let userId = authManager.user?.id else { return }

    isLoadingRecommendations = true
    defer { isLoadingRecommendations = false }

    do {
      recommendations = try await recommendationService.fetchRecommendations(athleteId: userId, limit: 8)
      logger.info("Loaded \(self.recommendations.count) school recommendations")
    } catch {
      logger.error("Failed to load recommendations: \(error.localizedDescription)")
      recommendations = []
    }
  }

  /// Adds a recommended school with the same enrichment the Schools-page "Add School" flow
  /// runs on selection (NCAA division/conference, College Scorecard location/academic data,
  /// favicon) — otherwise onboarding-added schools save with those fields null. See
  /// AddSchoolViewModel+NcaaLookup.swift / +Enrichment.swift for the reference flow.
  func addSchool(_ recommendation: SchoolRecommendation) async -> Bool {
    guard let userId = authManager.user?.id else { return false }

    do {
      let familyUnit = try await familyService.getFamilyUnit(forUserId: userId)
      guard let familyUnitId = familyUnit?.id else {
        logger.warning("No family unit found; cannot create school")
        return false
      }

      var division = recommendation.division.flatMap(Division.init(rawValue:))
      var conference = recommendation.conference
      if division == nil || conference == nil,
         let ncaaResult = await ncaaDatabase.lookup(schoolName: recommendation.name) {
        division = division ?? ncaaResult.division
        conference = conference ?? ncaaResult.conference
      }

      let scorecardData = try? await collegeScorecardService.lookupCollege(name: recommendation.name)

      let form = SchoolFormState(
        name: recommendation.name,
        state: recommendation.state ?? "",
        division: division,
        conference: conference ?? "",
        website: recommendation.website ?? scorecardData?.website ?? "",
        status: .researching
      )
      let request = SchoolCreateRequest.from(
        form: form,
        scorecardData: scorecardData,
        userId: userId,
        familyUnitId: familyUnitId
      )
      let created = try await schoolsRepository.createSchool(request: request)
      await faviconService.fetchAndPersist(school: created)

      recommendations.removeAll { $0.catalogKey == recommendation.catalogKey }
      schoolsAdded += 1

      OnboardingAnalytics.schoolAdded(schoolName: recommendation.name)
      logger.info("Added school from recommendation: \(recommendation.name)")
      return true
    } catch {
      logger.error("Failed to add school: \(error.localizedDescription)")
      errorMessage = "Couldn't add \(recommendation.name). Please try again."
      return false
    }
  }

  func dismissRecommendation(_ recommendation: SchoolRecommendation) async {
    guard let userId = authManager.user?.id else { return }

    recommendations.removeAll { $0.catalogKey == recommendation.catalogKey }

    do {
      try await recommendationService.dismissRecommendation(catalogKey: recommendation.catalogKey, athleteId: userId)
      logger.info("Dismissed recommendation: \(recommendation.name)")
    } catch {
      logger.error("Failed to dismiss recommendation: \(error.localizedDescription)")
    }
  }

  // MARK: - Complete

  func completeOnboarding() async -> Bool {
    guard let userId = authManager.user?.id else {
      errorMessage = "User not authenticated"
      return false
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let assessment = OnboardingAssessment.defaultForOnboarding
      let startingPhase = OnboardingAssessment.startingPhase(for: assessment, graduationYear: graduationYear)
      try await onboardingService.completeOnboarding(
        userId: userId,
        assessment: assessment,
        startingPhase: startingPhase
      )
      OnboardingAnalytics.onboardingComplete(completedItems: schoolsAdded)
      logger.info("Onboarding v2 complete, schools added: \(self.schoolsAdded)")
      return true
    } catch {
      logger.error("Failed to complete onboarding: \(error.localizedDescription)")
      errorMessage = "Couldn't finish setup. Please try again."
      return false
    }
  }

  func clearError() {
    errorMessage = nil
  }
}
