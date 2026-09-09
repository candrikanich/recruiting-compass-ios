import Testing
@testable import TheRecruitingCompass

@MainActor
@Suite("InboundDraftsViewModel")
struct InboundDraftsViewModelTests {

  private func makeDraft(
    id: String = "d1",
    matchedSchoolId: String? = nil,
    status: String = "pending"
  ) -> InboundEmailDraft {
    InboundEmailDraft(
      id: id, familyUnitId: "fam-1", rawEmailId: nil, matchedCoachId: nil,
      matchedSchoolId: matchedSchoolId, senderName: "Coach Smith", senderEmail: "coach@school.edu",
      subject: "Great game", bodyText: "Body", occurredAt: "2026-09-01T00:00:00Z",
      status: status, confirmedInteractionId: nil, createdAt: "2026-09-01T00:00:00Z"
    )
  }

  private func makeViewModel(api: MockInboundDraftsAPIService) -> InboundDraftsViewModel {
    let mockAuth = MockAuthManager()
    let user = User(id: "u1", email: "a@b.com", emailConfirmedAt: nil, phone: nil, fullName: nil, createdAt: "", updatedAt: "", role: nil, dateOfBirth: nil)
    mockAuth.user = user
    mockAuth.setMockSession(Session(
      accessToken: "test-token", tokenType: "bearer", expiresIn: 3600,
      expiresAt: 9_999_999_999, refreshToken: "refresh",
      user: user
    ))
    let familyManager = FamilyManager(familyService: MockFamilyService(), authManager: mockAuth)
    return InboundDraftsViewModel(apiService: api, familyManager: familyManager, authManager: mockAuth)
  }

  @Test func loadDraftsPopulatesFromService() async {
    let api = MockInboundDraftsAPIService()
    api.draftsToReturn = [makeDraft()]
    let viewModel = makeViewModel(api: api)

    await viewModel.loadDrafts()

    #expect(viewModel.drafts.count == 1)
    #expect(viewModel.errorMessage == nil)
    #expect(viewModel.isLoading == false)
  }

  @Test func loadDraftsSetsErrorMessageOnFailure() async {
    let api = MockInboundDraftsAPIService()
    api.errorToThrow = InboundDraftsAPIError.server(500)
    let viewModel = makeViewModel(api: api)

    await viewModel.loadDrafts()

    #expect(viewModel.drafts.isEmpty)
    #expect(viewModel.errorMessage != nil)
  }

  // MARK: - Review (#113: Confirm opens the editable form rather than blind-accepting)

  @Test func reviewDraftSetsDraftToReview() {
    let api = MockInboundDraftsAPIService()
    let viewModel = makeViewModel(api: api)
    let draft = makeDraft()

    viewModel.reviewDraft(draft)

    #expect(viewModel.draftToReview?.id == draft.id)
  }

  @Test func reviewDraftWorksEvenWhenUnmatched() {
    // Web parity: Confirm always opens the form now — the form's own
    // required school field replaces the old inline per-card gating.
    let api = MockInboundDraftsAPIService()
    let viewModel = makeViewModel(api: api)
    let unmatched = makeDraft(matchedSchoolId: nil)

    viewModel.reviewDraft(unmatched)

    #expect(viewModel.draftToReview?.id == unmatched.id)
  }

  @Test func handleDraftConfirmedRemovesDraftAndClosesSheet() async {
    let api = MockInboundDraftsAPIService()
    let draft = makeDraft(matchedSchoolId: "school-1")
    api.draftsToReturn = [draft]
    let viewModel = makeViewModel(api: api)
    await viewModel.loadDrafts()
    viewModel.reviewDraft(draft)

    viewModel.handleDraftConfirmed(draft.id)

    #expect(viewModel.drafts.isEmpty)
    #expect(viewModel.draftToReview == nil)
  }

  @Test func familyUnitIdAndCurrentUserIdExposeAuthState() {
    let api = MockInboundDraftsAPIService()
    let viewModel = makeViewModel(api: api)

    #expect(viewModel.currentUserId == "u1")
  }

  // MARK: - Discard (unchanged fast path)

  @Test func discardRemovesDraftFromListOnSuccess() async {
    let api = MockInboundDraftsAPIService()
    let draft = makeDraft()
    api.draftsToReturn = [draft]
    let viewModel = makeViewModel(api: api)
    await viewModel.loadDrafts()

    await viewModel.discard(draft)

    #expect(viewModel.drafts.isEmpty)
    #expect(api.discardCallCount == 1)
  }

  @Test func discardFailureLeavesDraftInListAndShowsToast() async {
    let api = MockInboundDraftsAPIService()
    let draft = makeDraft()
    api.draftsToReturn = [draft]
    let viewModel = makeViewModel(api: api)
    await viewModel.loadDrafts()
    api.errorToThrow = InboundDraftsAPIError.server(500)

    await viewModel.discard(draft)

    #expect(viewModel.drafts.count == 1)
    #expect(viewModel.showErrorToast)
  }
}
