import Testing
import Foundation
@testable import TheRecruitingCompass

// MARK: - First-run school step (ios#488, parity with web#1536)

@Suite("OnboardingV2ViewModel — first-run school step")
@MainActor
struct OnboardingV2ViewModelFirstRunTests {

  private func makeAuth(role: UserRole = .player) -> MockAuthManager {
    let auth = MockAuthManager()
    auth.setMockUser(User(
      id: "user-1", email: "test@example.com", emailConfirmedAt: nil,
      createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z", role: role
    ))
    return auth
  }

  private func makeSUT(
    repo: SpySchoolsRepository = SpySchoolsRepository(),
    scorecard: StubCollegeScorecardService = StubCollegeScorecardService(),
    onboarding: MockOnboardingService = MockOnboardingService(),
    familyService: StubFamilyService = StubFamilyService(),
    recommendations: RecordingRecommendationService = RecordingRecommendationService(),
    role: UserRole = .player
  ) -> OnboardingV2ViewModel {
    OnboardingV2ViewModel(
      onboardingService: onboarding,
      preferenceService: StubPreferenceService(),
      authManager: makeAuth(role: role),
      schoolsRepository: repo,
      recommendationService: recommendations,
      familyService: familyService,
      ncaaDatabase: StubNcaaDatabase(),
      collegeScorecardService: scorecard,
      faviconService: SpyFaviconService()
    )
  }

  private let ohioState = CollegeSearchResult(
    id: "204796", name: "Ohio State University", city: "Columbus", state: "OH", website: "osu.edu"
  )

  @Test func pickingASchoolAddsItAsAFavorite() async {
    let repo = SpySchoolsRepository()
    let vm = makeSUT(repo: repo)

    let added = await vm.pickSchool(ohioState)

    #expect(added)
    #expect(repo.lastCreateRequest?.name == "Ohio State University")
    #expect(repo.lastCreateRequest?.isFavorite == true)
    #expect(vm.schoolsAdded == 1)
    #expect(vm.pickedSchoolName == "Ohio State University")
  }

  @Test func pickingASchoolAlreadyOnTheListStarsItInsteadOfDuplicating() async {
    let repo = SpySchoolsRepository()
    repo.existingSchools = [School.mock(id: "school-9", name: "Ohio State University")]
    let vm = makeSUT(repo: repo)

    let added = await vm.pickSchool(ohioState)

    #expect(added)
    #expect(repo.createCallCount == 0)
    #expect(repo.favoriteToggles.map(\.id) == ["school-9"])
    #expect(repo.favoriteToggles.map(\.isFavorite) == [true])
    #expect(vm.pickedSchoolName == "Ohio State University")
  }

  @Test func recommendationAddsStayOutOfFavorites() async {
    let repo = SpySchoolsRepository()
    let vm = makeSUT(repo: repo)
    let recommendation = SchoolRecommendation(
      catalogKey: "bgsu", name: "Bowling Green State University", division: "D1", conference: nil,
      state: "OH", website: nil, athleticsUrl: nil, score: 1.0, reasons: []
    )

    _ = await vm.addSchool(recommendation)

    #expect(repo.lastCreateRequest?.isFavorite == nil)
  }

  @Test func failedPickReportsNoSchoolAndAHumanMessage() async {
    let family = StubFamilyService()
    family.stubbedFamilyUnit = nil
    let vm = makeSUT(familyService: family)

    let added = await vm.pickSchool(ohioState)

    #expect(!added)
    #expect(vm.pickedSchoolName == nil)
    #expect(vm.schoolsAdded == 0)
    #expect(vm.errorMessage == "Couldn't add Ohio State University. Try again in a moment.")
  }

  @Test func searchIsUsableWithNoRecommendations() async {
    let scorecard = StubCollegeScorecardService()
    scorecard.stubbedSearchResults = [ohioState]
    let vm = makeSUT(scorecard: scorecard)
    await vm.loadRecommendations()

    await vm.performSearch(query: "Ohio State")

    #expect(vm.recommendations.isEmpty)
    #expect(vm.searchResults == [ohioState])
  }

  @Test func searchWaitsForThreeCharacters() async {
    let scorecard = StubCollegeScorecardService()
    scorecard.stubbedSearchResults = [ohioState]
    let vm = makeSUT(scorecard: scorecard)

    await vm.performSearch(query: "Oh")

    #expect(vm.searchResults.isEmpty)
  }

  @Test func notSureYetCompletesWithNoSchoolAndNoError() async {
    let onboarding = MockOnboardingService()
    let vm = makeSUT(onboarding: onboarding)

    let finished = await vm.completeOnboarding()

    #expect(finished)
    #expect(vm.errorMessage == nil)
    #expect(vm.schoolsAdded == 0)
  }

  @Test func parentGetsTheParentPrompt() {
    #expect(makeSUT(role: .parent).schoolPrompt == "Which school is your athlete most excited about?")
    #expect(makeSUT(role: .player).schoolPrompt == "Which school are you most excited about?")
  }

  @Test func duplicatePickCountsAsTheFirstSchool() async {
    let repo = SpySchoolsRepository()
    repo.existingSchools = [School.mock(id: "school-9", name: "Ohio State University")]
    let vm = makeSUT(repo: repo)

    _ = await vm.pickSchool(ohioState)

    #expect(vm.schoolsAdded == 1)
    #expect(vm.hasAddedSchool)
  }

  @Test func concurrentTapsOnTheSameResultCreateOneSchool() async {
    let repo = SpySchoolsRepository()
    repo.createDelay = .milliseconds(100)
    let vm = makeSUT(repo: repo)

    async let first = vm.pickSchool(ohioState)
    async let second = vm.pickSchool(ohioState)
    let results = await [first, second]

    #expect(repo.createCallCount == 1)
    #expect(results.filter { $0 }.count == 1)
    #expect(vm.schoolsAdded == 1)
    #expect(!vm.isPickingSchool)
  }

  @Test func finishButtonSaysNotSureYetUntilASchoolIsAdded() async {
    let vm = makeSUT()
    #expect(vm.finishButtonTitle == "Not sure yet")

    _ = await vm.pickSchool(ohioState)

    #expect(vm.finishButtonTitle == "Go to dashboard")
  }

  @Test func recommendationsAndDismissalsBelongToTheConnectedAthlete() async {
    let recommendations = RecordingRecommendationService()
    let vm = makeSUT(recommendations: recommendations, role: .parent)
    vm.recommendationAthleteId = "athlete-9"
    let recommendation = SchoolRecommendation(
      catalogKey: "bgsu", name: "Bowling Green", division: nil, conference: nil,
      state: nil, website: nil, athleticsUrl: nil, score: 1, reasons: []
    )

    await vm.loadRecommendations()
    await vm.dismissRecommendation(recommendation)

    #expect(recommendations.fetchedAthleteIds == ["athlete-9"])
    #expect(recommendations.dismissedAthleteIds == ["athlete-9"])
  }

  @Test func recommendationsDefaultToTheSignedInUser() async {
    let recommendations = RecordingRecommendationService()
    let vm = makeSUT(recommendations: recommendations)

    await vm.loadRecommendations()

    #expect(recommendations.fetchedAthleteIds == ["user-1"])
  }

  @Test func cancelledSearchReleasesTheSpinner() async {
    let scorecard = StubCollegeScorecardService()
    scorecard.stubbedSearchResults = [ohioState]
    let vm = makeSUT(scorecard: scorecard)

    let task = Task { await vm.performSearch(query: "Ohio State") }
    task.cancel()
    await task.value

    #expect(!vm.isSearching)
  }

  @Test func shortQueryReleasesTheSpinner() async {
    let vm = makeSUT()
    vm.isSearching = true

    await vm.performSearch(query: "Oh")

    #expect(!vm.isSearching)
  }

  @Test func pickingASchoolCancelsAPendingSearch() async throws {
    let scorecard = StubCollegeScorecardService()
    scorecard.stubbedSearchResults = [ohioState]
    let vm = makeSUT(scorecard: scorecard)

    vm.handleSearchQueryChanged("Ohio State")
    _ = await vm.pickSchool(ohioState)
    try await Task.sleep(for: .milliseconds(500))

    #expect(vm.searchResults.isEmpty)
  }

  @Test func aSuccessfulPickDuringASearchReleasesTheSpinner() async {
    let scorecard = StubCollegeScorecardService()
    scorecard.stubbedSearchResults = [ohioState]
    scorecard.searchDelay = .milliseconds(200)
    let vm = makeSUT(scorecard: scorecard)

    let search = Task { await vm.performSearch(query: "Ohio State") }
    try? await Task.sleep(for: .milliseconds(50))
    #expect(vm.isSearching)
    _ = await vm.pickSchool(ohioState)
    await search.value

    #expect(!vm.isSearching)
  }

  @Test func aFailedPickDuringASearchReleasesTheSpinner() async {
    let family = StubFamilyService()
    family.stubbedFamilyUnit = nil
    let scorecard = StubCollegeScorecardService()
    scorecard.stubbedSearchResults = [ohioState]
    scorecard.searchDelay = .milliseconds(200)
    let vm = makeSUT(scorecard: scorecard, familyService: family)

    let search = Task { await vm.performSearch(query: "Ohio State") }
    try? await Task.sleep(for: .milliseconds(50))
    let added = await vm.pickSchool(ohioState)
    await search.value

    #expect(!added)
    #expect(!vm.isSearching)
  }

  @Test func pickingAnAlreadyStarredSchoolAddsNothingAndReportsNothing() async {
    let harness = AnalyticsHarness()
    defer { harness.restore() }
    let repo = SpySchoolsRepository()
    repo.existingSchools = [School.mock(id: "school-9", name: "Ohio State University").with(isFavorite: true)]
    let vm = makeSUT(repo: repo)

    let picked = await vm.pickSchool(ohioState)

    #expect(picked)
    #expect(vm.schoolsAdded == 0)
    #expect(repo.createCallCount == 0)
    #expect(repo.favoriteToggles.isEmpty)
    #expect(vm.pickedSchoolName == "Ohio State University")
    #expect(vm.hasAddedSchool)
    #expect(harness.transport.events(named: "onboarding_v2_school_added").isEmpty)
  }

  @Test func parentSeesTheIntroOnTheSchoolStep() {
    #expect(makeSUT(role: .parent).schoolStepIntro == FirstRunCopy.intro)
  }

  @Test func playerWhoSawStepOneDoesNotSeeTheIntroTwice() {
    let vm = makeSUT(role: .player)
    vm.playerSawStepOne = true
    #expect(vm.schoolStepIntro == nil)
  }

  @Test func playerWhoSkippedStepOneSeesTheIntroOnTheSchoolStep() {
    let vm = makeSUT(role: .player)
    vm.playerSawStepOne = false
    #expect(vm.schoolStepIntro == FirstRunCopy.intro)
  }
}
