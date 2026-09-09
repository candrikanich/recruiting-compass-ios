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

  @Test func confirmSendsEditedFormValuesAndRemovesDraftOnSuccess() async throws {
    let api = MockInboundDraftsAPIService()
    let draft = makeDraft(matchedSchoolId: "school-1")
    api.draftsToReturn = [draft]
    let viewModel = makeViewModel(api: api)
    await viewModel.loadDrafts()

    var formState = InteractionFormState(fromDraft: draft)
    formState.schoolId = "picked-school"
    formState.coachId = "coach-9"
    formState.subject = "Edited subject"

    let interactionId = try await viewModel.confirm(draft, with: formState)

    #expect(interactionId == "interaction-1")
    #expect(viewModel.drafts.isEmpty)
    #expect(api.confirmCallCount == 1)
    #expect(api.lastConfirmedSchoolId == "picked-school")
    #expect(api.lastConfirmedCoachId == .some("coach-9"))
    #expect(api.lastConfirmedType == "email")
    #expect(api.lastConfirmedDirection == "inbound")
    #expect(api.lastConfirmedSubject == "Edited subject")
  }

  @Test func confirmSendsExplicitNullCoachIdWhenCleared() async throws {
    let api = MockInboundDraftsAPIService()
    let draft = makeDraft(matchedSchoolId: "school-1")
    api.draftsToReturn = [draft]
    let viewModel = makeViewModel(api: api)
    await viewModel.loadDrafts()

    var formState = InteractionFormState(fromDraft: draft)
    formState.coachId = nil

    _ = try await viewModel.confirm(draft, with: formState)

    #expect(api.lastConfirmedCoachId == .some(nil))
  }

  @Test func confirmFailurePropagatesErrorAndLeavesDraftInList() async {
    let api = MockInboundDraftsAPIService()
    let draft = makeDraft(matchedSchoolId: "school-1")
    api.draftsToReturn = [draft]
    let viewModel = makeViewModel(api: api)
    await viewModel.loadDrafts()
    api.errorToThrow = InboundDraftsAPIError.server(500)

    await #expect(throws: InboundDraftsAPIError.self) {
      _ = try await viewModel.confirm(draft, with: InteractionFormState(fromDraft: draft))
    }
    #expect(viewModel.drafts.count == 1)
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
