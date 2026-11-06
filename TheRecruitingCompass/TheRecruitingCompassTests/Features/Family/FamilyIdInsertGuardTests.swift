import XCTest
@testable import TheRecruitingCompass

/// #389: no insert payload may carry a missing or "" `family_unit_id`. A missing family is an invariant
/// violation (web#1237), so each create path refuses before any network call.
@MainActor
final class FamilyIdInsertGuardTests: XCTestCase {
  nonisolated deinit {}

  private let missing: [String?] = [nil, "", "  "]
  private let copy = "Your family account is still loading. Please wait a moment and try again."

  // MARK: - Request types cannot be built without a family

  func testCoachRequest_missingFamily_throws() {
    for family in missing {
      XCTAssertThrowsError(try CoachCreateRequest(
        schoolId: "s1", userId: "u1", familyUnitId: family, role: "head", firstName: "A", lastName: "B"
      ))
      var form = CoachFormState()
      form.role = .head
      form.firstName = "A"
      form.lastName = "B"
      XCTAssertThrowsError(try CoachCreateRequest.from(
        form: form, schoolId: "s1", userId: "u1", familyUnitId: family
      ))
    }
  }

  func testCoachRequest_withFamily_stampsAndEncodesIt() throws {
    let request = try CoachCreateRequest(
      schoolId: "s1", userId: "u1", familyUnitId: "fam-1", role: "head", firstName: "A", lastName: "B"
    )
    let json = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
    )
    XCTAssertEqual(json["family_unit_id"] as? String, "fam-1")
  }

  func testSchoolRequest_missingFamily_throws() {
    for family in missing {
      var form = SchoolFormState()
      form.name = "Harvard"
      XCTAssertThrowsError(try SchoolCreateRequest.from(
        form: form, scorecardData: nil, userId: "u1", familyUnitId: family
      ))
      let recommendation = SchoolRecommendation(catalogKey: "k1", name: "State U", score: 0.9, reasons: [])
      XCTAssertThrowsError(try SchoolCreateRequest.from(
        recommendation: recommendation, userId: "u1", familyUnitId: family
      ))
    }
  }

  func testSchoolRequest_withFamily_stampsAndEncodesIt() throws {
    var form = SchoolFormState()
    form.name = "Harvard"
    let request = try SchoolCreateRequest.from(form: form, scorecardData: nil, userId: "u1", familyUnitId: "fam-1")
    let json = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
    )
    XCTAssertEqual(json["family_unit_id"] as? String, "fam-1")
  }

  func testInteractionRequest_missingFamily_throws() {
    for family in missing {
      XCTAssertThrowsError(try Self.interaction(family: family))
    }
  }

  func testInteractionRequest_withFamily_stampsAndEncodesIt() throws {
    let request = try Self.interaction(family: "fam-1")
    let json = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
    )
    XCTAssertEqual(json["family_unit_id"] as? String, "fam-1")
  }

  private static func interaction(family: String?) throws -> InteractionCreateRequest {
    try InteractionCreateRequest(
      schoolId: "s1", coachId: nil, type: .email, direction: .outbound, occurredAt: Date(),
      subject: nil, content: nil, sentiment: nil, loggedBy: "u1", familyUnitId: family
    )
  }

  // MARK: - View models refuse before any network call

  func testAddCoach_missingFamily_doesNotInsert() async {
    for family in missing {
      let service = MockCoachesService()
      let vm = AddCoachViewModel(coachesService: service, familyUnitId: family, userId: "u1")
      vm.formState.selectedSchoolId = "school-1"
      vm.formState.role = .head
      vm.formState.firstName = "John"
      vm.formState.lastName = "Smith"

      let result = await vm.submitCoach()

      XCTAssertNil(result)
      XCTAssertEqual(service.createCoachCallCount, 0)
      XCTAssertEqual(vm.submitError, copy)
    }
  }

  func testAddCoach_withFamily_stillStampsIt() async {
    let service = MockCoachesService()
    service.mockCreatedCoach = Coach.mock(id: "c1", firstName: "John", lastName: "Smith")
    let vm = AddCoachViewModel(coachesService: service, familyUnitId: "fam-1", userId: "u1")
    vm.formState.selectedSchoolId = "school-1"
    vm.formState.role = .head
    vm.formState.firstName = "John"
    vm.formState.lastName = "Smith"

    _ = await vm.submitCoach()

    XCTAssertEqual(service.lastCreateCoachRequest?.familyUnitId, "fam-1")
  }

  func testAddSchool_missingFamily_doesNotInsert() async {
    for family in missing {
      let service = MockSchoolsService()
      let vm = AddSchoolViewModel(schoolsService: service, familyUnitId: family, userId: "u1")
      vm.formState.name = "Harvard University"
      vm.formState.status = .recruited

      let result = await vm.submitSchool()

      XCTAssertNil(result)
      XCTAssertEqual(service.createSchoolCallCount, 0)
      XCTAssertEqual(service.fetchSchoolsCallCount, 0, "no family-scoped read with a missing id either")
      XCTAssertEqual(vm.submitError, copy)
    }
  }

  func testAddInteraction_missingFamily_doesNotInsertInteractionOrCoach() async {
    for family in missing {
      let service = MockInteractionsService()
      let vm = AddInteractionViewModel(interactionsService: service, familyUnitId: family, userId: "u1")
      vm.formState.schoolId = "school1"
      vm.formState.type = .email
      vm.formState.subject = "Hi"
      vm.formState.content = "Hello"
      vm.newCoachForm.firstName = "John"
      vm.newCoachForm.lastName = "Smith"
      vm.newCoachForm.role = .head

      let logged = await vm.submitInteraction()
      let coachAdded = await vm.createNewCoach()

      XCTAssertFalse(logged)
      XCTAssertFalse(coachAdded)
      XCTAssertEqual(service.createInteractionCallCount, 0)
      XCTAssertEqual(service.createCoachCallCount, 0)
      XCTAssertEqual(vm.errorMessage, copy)
    }
  }

  func testQuickCommunication_blankFamily_doesNotLogInteraction() async {
    let interactions = MockInteractionsService()
    let coach = Coach(id: "c1", firstName: "Sam", lastName: "Smith", email: "s@x.com", phone: "555",
                      position: "HC", schoolId: "s1", createdAt: "", updatedAt: "")
    let vm = QuickCommunicationViewModel(
      coach: coach, interactionsService: interactions, coachesService: MockCoachesService(),
      loggedBy: "u1", familyUnitId: ""
    )

    await vm.logInstagramDM()
    await vm.logSend(.email)

    XCTAssertEqual(interactions.createInteractionCallCount, 0)
    XCTAssertNotNil(vm.errorMessage)
  }

  func testSendProfile_blankFamily_doesNotLogInteraction() async {
    let interactions = MockInteractionsService()
    let auth = MockAuthManager()
    auth.setMockUser(User(
      id: "u1", email: "o@x.com", emailConfirmedAt: nil, fullName: "Owen",
      createdAt: "", updatedAt: "", role: nil, dateOfBirth: nil
    ))
    let vm = SendProfileViewModel(
      service: MockPublicProfileManaging(), authManager: auth, preferenceService: MockPreferenceService(),
      photoService: MockProfilePhotoService(), interactionsService: interactions
    )
    let message = SendProfileMessage(
      coachId: "c1", schoolId: "s1", familyUnitId: "", coachEmail: "c@x.edu", coachPhone: nil,
      subject: "s", emailBody: "b", textBody: "t", url: URL(string: "https://app.example.com/p/x")!
    )

    await vm.logSend(.email, message: message)

    XCTAssertEqual(interactions.createInteractionCallCount, 0)
    XCTAssertNotNil(vm.errorMessage)
  }
}
