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
  /// The school the player picked from search, shown as a confirmation under the search field.
  var pickedSchoolName: String?
  var searchResults: [CollegeSearchResult] = []
  var isSearching = false
  var searchError: String?
  /// True while a search pick is being saved; blocks a second tap from inserting twice.
  private(set) var isPickingSchool = false
  /// Whose recommendations to load and dismiss. Nil means the signed-in user; a parent on the school step
  /// sets the connected athlete's id, since recommendations belong to the athlete.
  var recommendationAthleteId: String?

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

  var schoolPrompt: String {
    FirstRunCopy.schoolPrompt(for: authManager.user?.role)
  }

  var hasAddedSchool: Bool { schoolsAdded > 0 || pickedSchoolName != nil }

  /// Set by the player container: true when step 1 was shown, so the intro already appeared there.
  var playerSawStepOne = false

  /// The intro sits on step 1; the school step carries it only when step 1 did not (player) or for a parent,
  /// whose first first-run screen is the school step (web#1536 shows it on the school-only step).
  var schoolStepIntro: String? {
    let isParent = authManager.user?.role == .parent
    return isParent || !playerSawStepOne ? FirstRunCopy.intro : nil
  }

  var finishButtonTitle: String {
    hasAddedSchool ? "Go to dashboard" : FirstRunCopy.skipLabel
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
    guard let userId = recommendationAthleteId ?? authManager.user?.id else { return }

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
      let familyUnitId = try await requireFamilyUnitId(userId: userId)
      let request = try await makeRequest(
        name: recommendation.name,
        state: recommendation.state,
        division: recommendation.division.flatMap(Division.init(rawValue:)),
        conference: recommendation.conference,
        website: recommendation.website,
        scorecardLookup: { [collegeScorecardService] in
          try await collegeScorecardService.lookupCollege(name: recommendation.name)
        },
        isFavorite: nil,
        userId: userId,
        familyUnitId: familyUnitId
      )
      try await persist(request)
      schoolsAdded += 1

      recommendations.removeAll { $0.catalogKey == recommendation.catalogKey }
      OnboardingAnalytics.schoolAdded()
      logger.info("Added school from recommendation")
      return true
    } catch let error as FamilyUnitID.MissingError {
      logger.warning("No family unit found; refusing to create school")
      errorMessage = error.localizedDescription
      return false
    } catch {
      logger.error("Failed to add school: \(error.localizedDescription)")
      errorMessage = "Couldn't add \(recommendation.name). Please try again."
      return false
    }
  }

  /// First-run pick from search: the school is added and starred as a favorite (web#1536). A school already
  /// on the family's list is starred instead of duplicated, so picking it again still means "favorite".
  func pickSchool(_ college: CollegeSearchResult) async -> Bool {
    guard !isPickingSchool, let userId = authManager.user?.id else { return false }
    isPickingSchool = true
    defer { isPickingSchool = false }
    // A pending or in-flight search must not put results back over a school that was just picked.
    searchDebounceTask?.cancel()
    searchGeneration += 1
    // The superseded search's own defer no longer clears the spinner, so release it here.
    isSearching = false

    do {
      let familyUnitId = try await requireFamilyUnitId(userId: userId)
      let request = try await makeRequest(
        name: college.name,
        state: college.state,
        division: nil,
        conference: nil,
        website: college.website,
        scorecardLookup: { [collegeScorecardService] in
          try await collegeScorecardService.lookupCollege(id: college.id)
        },
        isFavorite: true,
        userId: userId,
        familyUnitId: familyUnitId
      )

      let existing = try await schoolsRepository.fetchSchools(familyUnitId: familyUnitId)
      if let duplicate = DuplicateDetector.findDuplicate(in: existing, for: request).duplicate {
        pickedSchoolName = duplicate.name
        searchResults = []
        // Already starred: nothing was added, so it neither counts nor reports again.
        guard !duplicate.isFavorite else { return true }
        try await schoolsRepository.toggleFavorite(id: duplicate.id, isFavorite: true)
      } else {
        try await persist(request)
        pickedSchoolName = college.name
      }
      schoolsAdded += 1

      searchResults = []
      OnboardingAnalytics.schoolAdded()
      logger.info("Picked first-run school from search")
      return true
    } catch {
      logger.error("Failed to pick school: \(error.localizedDescription)")
      errorMessage = "Couldn't add \(college.name). Try again in a moment."
      return false
    }
  }

  private func requireFamilyUnitId(userId: String) async throws -> String {
    let familyUnit = try await familyService.getFamilyUnit(forUserId: userId)
    return try FamilyUnitID.require(familyUnit?.id)
  }

  private func makeRequest(
    name: String,
    state: String?,
    division: Division?,
    conference: String?,
    website: String?,
    scorecardLookup: () async throws -> CollegeDataResult?,
    isFavorite: Bool?,
    userId: String,
    familyUnitId: String
  ) async throws -> SchoolCreateRequest {
    var division = division
    var conference = conference
    if division == nil || conference == nil,
       let ncaaResult = await ncaaDatabase.lookup(schoolName: name) {
      division = division ?? ncaaResult.division
      conference = conference ?? ncaaResult.conference
    }

    var scorecardData: CollegeDataResult?
    do {
      scorecardData = try await scorecardLookup()
    } catch {
      // Best-effort: an enrichment failure must not block adding the school itself —
      // it just saves without location/academic data instead.
      logger.warning("Scorecard enrichment failed for \(name): \(error.localizedDescription)")
    }

    let city = scorecardData?.city ?? ""
    let resolvedState = state ?? scorecardData?.state ?? ""
    let form = SchoolFormState(
      name: name,
      location: [city, resolvedState].filter { !$0.isEmpty }.joined(separator: ", "),
      city: city,
      state: resolvedState,
      division: division,
      conference: conference ?? "",
      website: website ?? scorecardData?.website ?? "",
      status: .researching
    )
    return try SchoolCreateRequest.from(
      form: form,
      scorecardData: scorecardData,
      userId: userId,
      familyUnitId: familyUnitId,
      isFavorite: isFavorite
    )
  }

  private func persist(_ request: SchoolCreateRequest) async throws {
    let created = try await schoolsRepository.createSchool(request: request)

    // Fire-and-forget, matching AddSchoolViewModel+DuplicateDetection.swift's
    // createSchoolInternal — awaiting here would leave the Add button re-tappable
    // on the same recommendation until the favicon fetch resolves.
    let favicon = faviconService
    Task {
      await favicon.fetchAndPersist(school: created)
    }
  }

  // MARK: - Search

  private var searchDebounceTask: Task<Void, Never>?
  private var searchGeneration = 0

  func handleSearchQueryChanged(_ text: String) {
    searchDebounceTask?.cancel()
    searchDebounceTask = Task {
      try? await Task.sleep(for: .milliseconds(300))
      if !Task.isCancelled { await performSearch(query: text) }
    }
  }

  func performSearch(query: String) async {
    searchGeneration += 1
    let generation = searchGeneration
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    guard trimmed.count >= 3 else {
      searchResults = []
      searchError = nil
      isSearching = false
      return
    }

    isSearching = true
    searchError = nil
    // Only the newest search owns the spinner; a cancelled or superseded one must still release it.
    defer { if searchGeneration == generation { isSearching = false } }

    do {
      let results = try await collegeScorecardService.searchColleges(query: trimmed)
      guard !Task.isCancelled, searchGeneration == generation else { return }
      searchResults = results
    } catch is CancellationError {
      return
    } catch {
      guard searchGeneration == generation else { return }
      logger.error("First-run school search failed: \(error.localizedDescription)")
      searchResults = []
      searchError = "Couldn't search schools. Check your connection and try again."
    }
  }

  func dismissRecommendation(_ recommendation: SchoolRecommendation) async {
    guard let userId = recommendationAthleteId ?? authManager.user?.id else { return }

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
      OnboardingAnalytics.onboardingComplete(role: .player, completedItems: schoolsAdded)
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
