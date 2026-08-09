import XCTest
@testable import TheRecruitingCompass

@MainActor
final class PlayerDetailsViewModelTests: XCTestCase {
  nonisolated deinit {}
  var viewModel: PlayerDetailsViewModel!
  var mockService: MockPreferenceManager!
  var mockPhoto: MockProfilePhotoService!

  override func setUp() async throws {
    try await super.setUp()
    mockService = MockPreferenceManager()
    mockPhoto = MockProfilePhotoService()
  }

  override func tearDown() {
    viewModel = nil
    mockService = nil
    mockPhoto = nil
    super.tearDown()
  }

  // MARK: - Load/Save Tests

  func testLoadDetails_WhenDetailsExist_LoadsData() async {
    // Given
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    let expectedDetails = PlayerDetails(
      graduationYear: 2026,
      highSchool: "Test High",
      clubTeam: "Elite Baseball",
      primarySport: "Baseball",
      primaryPosition: "Pitcher",
      positions: ["Pitcher", "First Base"],
      bats: "R",
      throws_: "R",
      heightInches: 72,
      weightLbs: 180,
      gpa: 3.8,
      satScore: 1350,
      actScore: 30
    )
    mockService.fetchPreferencesResult = .success(expectedDetails)

    // When
    await viewModel.loadDetails()

    // Then
    XCTAssertEqual(viewModel.details.graduationYear, 2026)
    XCTAssertEqual(viewModel.details.highSchool, "Test High")
    XCTAssertEqual(viewModel.details.gpa, 3.8)
    XCTAssertFalse(viewModel.isLoading)
  }

  func testLoadDetails_WhenNoDetails_UsesDefaults() async {
    // Given
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    mockService.fetchPreferencesResult = .success(nil)

    // When
    await viewModel.loadDetails()

    // Then
    XCTAssertEqual(viewModel.details, PlayerDetails.default)
    XCTAssertFalse(viewModel.isLoading)
  }

  func testSaveDetails_WhenAthlete_SavesSuccessfully() async {
    // Given
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    mockService.savePreferencesResult = .success(viewModel.details)

    // When
    await viewModel.saveDetails()

    // Then
    XCTAssertEqual(viewModel.saveStatus, .saved)
  }

  // MARK: - Family Collaboration Tests
  // Parents and players collaborate on one shared player profile; everyone can edit.

  func testInit_WhenParentRole_IsNotReadOnly() {
    // When
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .parent)

    // Then
    XCTAssertFalse(viewModel.isReadOnly)
  }

  func testInit_WhenPlayerRole_NotReadOnly() {
    // When
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)

    // Then
    XCTAssertFalse(viewModel.isReadOnly)
  }

  func testSaveDetails_WhenParentRole_SavesToAthleteRow() async {
    // Given a parent editing the athlete's profile
    viewModel = PlayerDetailsViewModel(
      preferenceService: mockService, userRole: .parent, targetUserId: "athlete-123")
    mockService.savePreferencesResult = .success(viewModel.details)

    // When
    await viewModel.saveDetails()

    // Then it saves, targeting the athlete's user id
    XCTAssertEqual(mockService.savePreferencesCalls.count, 1)
    XCTAssertEqual(mockService.savePreferencesCalls.first?.userId, "athlete-123")
    XCTAssertEqual(mockService.savePreferencesCalls.first?.category, .player)
  }

  func testMarkChanged_WhenParentRole_MarksChanges() {
    // Given
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .parent)

    // When
    viewModel.markChanged()

    // Then
    XCTAssertTrue(viewModel.hasUnsavedChanges)
  }

  func testLoadDetails_WithTargetUserId_FetchesAthleteRow() async {
    // Given a parent viewing the athlete's profile
    viewModel = PlayerDetailsViewModel(
      preferenceService: mockService, userRole: .parent, targetUserId: "athlete-123",
      photoService: mockPhoto)
    mockService.fetchPreferencesResult = .success(nil)

    // When
    await viewModel.loadDetails()

    // Then the fetch targets the athlete's user id
    XCTAssertEqual(mockService.fetchPreferencesCalls.first?.userId, "athlete-123")
    XCTAssertEqual(mockService.fetchPreferencesCalls.first?.category, .player)
  }

  func testLoadDetails_WithoutTargetUserId_FetchesOwnRow() async {
    // Given a player viewing their own profile (no explicit target)
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    mockService.fetchPreferencesResult = .success(nil)

    // When
    await viewModel.loadDetails()

    // Then the fetch uses nil (current user)
    XCTAssertNil(mockService.fetchPreferencesCalls.first?.userId)
  }

  // MARK: - Photo Upload Tests

  func testUploadProfilePhoto_WithValidImage_PersistsToTargetUser() async {
    // Given
    viewModel = PlayerDetailsViewModel(
      preferenceService: mockService, userRole: .player, targetUserId: "self-1",
      photoService: mockPhoto)
    mockPhoto.stubbedUploadURL = "https://example.com/new.jpg"
    let testImage = UIImage(systemName: "person.fill")!

    // When
    await viewModel.uploadProfilePhoto(testImage)

    // Then it persists via the photo service, targeting the resolved user id
    XCTAssertNotNil(viewModel.profileImage)
    XCTAssertEqual(viewModel.photoUrl, "https://example.com/new.jpg")
    XCTAssertEqual(mockPhoto.lastUploadUserId, "self-1")
    XCTAssertFalse(viewModel.isUploadingPhoto)
  }

  func testDeleteProfilePhoto_RemovesPhoto() async {
    // Given
    viewModel = PlayerDetailsViewModel(
      preferenceService: mockService, userRole: .player, targetUserId: "self-1",
      photoService: mockPhoto)
    viewModel.profileImage = UIImage(systemName: "person.fill")
    viewModel.photoUrl = "https://example.com/old.jpg"

    // When
    await viewModel.deleteProfilePhoto()

    // Then
    XCTAssertNil(viewModel.profileImage)
    XCTAssertNil(viewModel.photoUrl)
    XCTAssertEqual(mockPhoto.lastDeleteUserId, "self-1")
  }

  func testUploadProfilePhoto_WhenParentRole_PersistsToAthlete() async {
    // Given a parent editing the athlete's profile (parents can now edit)
    viewModel = PlayerDetailsViewModel(
      preferenceService: mockService, userRole: .parent, targetUserId: "athlete-123",
      photoService: mockPhoto)
    let testImage = UIImage(systemName: "person.fill")!

    // When
    await viewModel.uploadProfilePhoto(testImage)

    // Then the upload targets the athlete's user id
    XCTAssertNotNil(viewModel.profileImage)
    XCTAssertEqual(mockPhoto.lastUploadUserId, "athlete-123")
  }

  // MARK: - Field Validation Tests

  func testUpdateGPA_ValidRange_UpdatesValue() {
    // Given
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)

    // When
    viewModel.updateGPA(3.8)

    // Then
    XCTAssertEqual(viewModel.details.gpa, 3.8)
    XCTAssertTrue(viewModel.hasUnsavedChanges)
  }

  func testUpdateGPA_OutOfRange_DoesNotUpdate() {
    // Given
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)

    // When
    viewModel.updateGPA(6.0)  // Invalid (max 5.0)

    // Then
    XCTAssertNil(viewModel.details.gpa)
    XCTAssertFalse(viewModel.hasUnsavedChanges)
  }

  func testUpdateSAT_ValidRange_UpdatesValue() {
    // Given
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)

    // When
    viewModel.updateSAT(1350)

    // Then
    XCTAssertEqual(viewModel.details.satScore, 1350)
    XCTAssertTrue(viewModel.hasUnsavedChanges)
  }

  func testUpdateSAT_OutOfRange_DoesNotUpdate() {
    // Given
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)

    // When
    viewModel.updateSAT(300)  // Invalid (min 400)

    // Then
    XCTAssertNil(viewModel.details.satScore)
  }

  func testUpdateACT_ValidRange_UpdatesValue() {
    // Given
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)

    // When
    viewModel.updateACT(30)

    // Then
    XCTAssertEqual(viewModel.details.actScore, 30)
    XCTAssertTrue(viewModel.hasUnsavedChanges)
  }

  func testUpdateACT_OutOfRange_DoesNotUpdate() {
    // Given
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)

    // When
    viewModel.updateACT(40)  // Invalid (max 36)

    // Then
    XCTAssertNil(viewModel.details.actScore)
  }

  // MARK: - Height Conversion Tests

  func testUpdateHeight_ConvertsFeetAndInchesToTotal() {
    // Given
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)

    // When
    viewModel.updateHeight(feet: 6, inches: 0)

    // Then
    XCTAssertEqual(viewModel.details.heightInches, 72)
    XCTAssertTrue(viewModel.hasUnsavedChanges)
  }

  func testHeightFeet_ComputesCorrectly() {
    // Given
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    viewModel.details.heightInches = 75  // 6'3"

    // Then
    XCTAssertEqual(viewModel.heightFeet, 6)
  }

  func testHeightInchesRemainder_ComputesCorrectly() {
    // Given
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    viewModel.details.heightInches = 75  // 6'3"

    // Then
    XCTAssertEqual(viewModel.heightInchesRemainder, 3)
  }

  // MARK: - Integration Tests

  func testCompleteWorkflow_LoadUpdateSave() async {
    // Given
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    mockService.fetchPreferencesResult = .success(nil)
    mockService.savePreferencesResult = .success(viewModel.details)

    // When - Load
    await viewModel.loadDetails()
    XCTAssertEqual(viewModel.details, PlayerDetails.default)

    // When - Update fields
    viewModel.updateGraduationYear(2026)
    viewModel.updateGPA(3.8)
    viewModel.updateSAT(1350)
    viewModel.updateHeight(feet: 6, inches: 2)

    // Then
    XCTAssertTrue(viewModel.hasUnsavedChanges)
    XCTAssertEqual(viewModel.details.graduationYear, 2026)
    XCTAssertEqual(viewModel.details.gpa, 3.8)
    XCTAssertEqual(viewModel.details.satScore, 1350)
    XCTAssertEqual(viewModel.details.heightInches, 74)

    // When - Save
    await viewModel.saveDetails()

    // Then
    XCTAssertFalse(viewModel.hasUnsavedChanges)
    XCTAssertEqual(mockService.savePreferencesCalls.count, 1)
  }

  // MARK: - SaveStatus Tests

  func testSaveStatus_DefaultIsIdle() {
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    XCTAssertEqual(viewModel.saveStatus, .idle)
  }

  func testSaveStatus_AfterSuccessfulSave_IsSaved() async {
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    mockService.savePreferencesResult = .success(viewModel.details)
    await viewModel.saveDetails()
    XCTAssertEqual(viewModel.saveStatus, .saved)
  }

  func testCompletenessScore_EmptyDetails_IsZero() {
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    XCTAssertEqual(viewModel.completenessScore, 0.0)
  }

  func testCompletenessScore_WithManyFieldsFilled_IsHigh() {
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    viewModel.details.graduationYear = 2026
    viewModel.details.highSchool = "Test High"
    viewModel.details.primarySport = "Soccer"
    viewModel.details.schoolName = "Test School"
    viewModel.details.schoolCity = "Austin"
    viewModel.details.schoolState = "TX"
    viewModel.details.heightInches = 72
    viewModel.details.weightLbs = 180
    viewModel.details.gpa = 3.8
    viewModel.details.satScore = 1350
    viewModel.details.actScore = 30
    viewModel.details.twitterHandle = "@test"
    XCTAssertGreaterThan(viewModel.completenessScore, 0.8)
  }

  func testNormalizePositions_TitleCasesAll() {
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    viewModel.details.positions = ["pitcher", "FIRST BASE", "outfielder"]
    viewModel.normalizePositions()
    XCTAssertEqual(viewModel.details.positions, ["Pitcher", "First Base", "Outfielder"])
  }

  func testNormalizePositions_NilPositions_StaysNil() {
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    viewModel.details.positions = nil
    viewModel.normalizePositions()
    XCTAssertNil(viewModel.details.positions)
  }

  func testIsBaseballOrSoftball_WhenBaseball_ReturnsTrue() {
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    viewModel.details.primarySport = "Baseball"
    XCTAssertTrue(viewModel.isBaseballOrSoftball)
  }

  func testIsBaseballOrSoftball_WhenSoftball_ReturnsTrue() {
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    viewModel.details.primarySport = "Softball"
    XCTAssertTrue(viewModel.isBaseballOrSoftball)
  }

  func testIsBaseballOrSoftball_WhenSoccer_ReturnsFalse() {
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    viewModel.details.primarySport = "Soccer"
    XCTAssertFalse(viewModel.isBaseballOrSoftball)
  }

  func testIsBaseballOrSoftball_WhenNil_ReturnsFalse() {
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    viewModel.details.primarySport = nil
    XCTAssertFalse(viewModel.isBaseballOrSoftball)
  }
}
