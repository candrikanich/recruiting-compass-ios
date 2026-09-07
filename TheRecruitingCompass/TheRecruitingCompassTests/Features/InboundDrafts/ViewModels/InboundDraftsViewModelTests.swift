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
    mockAuth.setMockSession(Session(
      accessToken: "test-token", tokenType: "bearer", expiresIn: 3600,
      expiresAt: 9_999_999_999, refreshToken: "refresh",
      user: User(id: "u1", email: "a@b.com", emailConfirmedAt: nil, phone: nil, fullName: nil, createdAt: "", updatedAt: "", role: nil, dateOfBirth: nil)
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

  @Test func canConfirmIsTrueWhenAlreadyMatched() {
    let api = MockInboundDraftsAPIService()
    let viewModel = makeViewModel(api: api)
    let matched = makeDraft(matchedSchoolId: "school-1")

    #expect(viewModel.canConfirm(matched))
  }

  @Test func canConfirmIsFalseWhenUnmatchedAndNoPick() {
    let api = MockInboundDraftsAPIService()
    let viewModel = makeViewModel(api: api)
    let unmatched = makeDraft(matchedSchoolId: nil)

    #expect(!viewModel.canConfirm(unmatched))
  }

  @Test func canConfirmIsTrueWhenUnmatchedButSchoolPicked() {
    let api = MockInboundDraftsAPIService()
    let viewModel = makeViewModel(api: api)
    let unmatched = makeDraft(id: "d2", matchedSchoolId: nil)
    viewModel.pickedSchoolId["d2"] = "picked-school"

    #expect(viewModel.canConfirm(unmatched))
  }

  @Test func confirmRemovesDraftFromListOnSuccess() async {
    let api = MockInboundDraftsAPIService()
    let draft = makeDraft(matchedSchoolId: "school-1")
    api.draftsToReturn = [draft]
    let viewModel = makeViewModel(api: api)
    await viewModel.loadDrafts()

    await viewModel.confirm(draft)

    #expect(viewModel.drafts.isEmpty)
    #expect(api.confirmCallCount == 1)
    #expect(api.lastConfirmedSchoolId == nil) // already matched — no schoolId sent
  }

  @Test func confirmSendsPickedSchoolIdWhenUnmatched() async {
    let api = MockInboundDraftsAPIService()
    let draft = makeDraft(matchedSchoolId: nil)
    api.draftsToReturn = [draft]
    let viewModel = makeViewModel(api: api)
    await viewModel.loadDrafts()
    viewModel.pickedSchoolId[draft.id] = "picked-school"

    await viewModel.confirm(draft)

    #expect(api.lastConfirmedSchoolId == "picked-school")
    #expect(viewModel.drafts.isEmpty)
  }

  @Test func confirmFailureLeavesDraftInListAndShowsToast() async {
    let api = MockInboundDraftsAPIService()
    let draft = makeDraft(matchedSchoolId: "school-1")
    api.draftsToReturn = [draft]
    let viewModel = makeViewModel(api: api)
    await viewModel.loadDrafts()
    api.errorToThrow = InboundDraftsAPIError.server(500)

    await viewModel.confirm(draft)

    #expect(viewModel.drafts.count == 1)
    #expect(viewModel.showErrorToast)
    #expect(viewModel.toastMessage != nil)
  }

  @Test func confirmNotFoundRemovesDraftWithoutToast() async {
    let api = MockInboundDraftsAPIService()
    let draft = makeDraft(matchedSchoolId: "school-1")
    api.draftsToReturn = [draft]
    let viewModel = makeViewModel(api: api)
    await viewModel.loadDrafts()
    api.errorToThrow = InboundDraftsAPIError.notFound

    await viewModel.confirm(draft)

    #expect(viewModel.drafts.isEmpty)
    #expect(!viewModel.showErrorToast)
  }

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
