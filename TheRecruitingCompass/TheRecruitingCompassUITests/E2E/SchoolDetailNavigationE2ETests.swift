import XCTest

final class SchoolDetailNavigationE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: SchoolDetailScreenObject!
  private var testUserSetup: TestUserSetup!
  private var testDataHelper: SchoolTestDataHelper!
  private var testUser: TestUser?
  private var testSchoolId: String?

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    let supabaseURL = E2ETestEnvironment.supabaseURL
    let supabaseKey = E2ETestEnvironment.supabaseAnonKey
    app.launch()

    screen = SchoolDetailScreenObject(app: app)
    testUserSetup = TestUserSetup(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
    testDataHelper = SchoolTestDataHelper(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
  }

  override func tearDownWithError() throws {
    // Cleanup test data
    Task {
      if let schoolId = testSchoolId {
        try? await testDataHelper?.deleteSchool(schoolId: schoolId)
      }
      if let userId = testUser?.id {
        try? await testUserSetup?.deleteTestUser(userId: userId)
      }
    }

    app = nil
    screen = nil
    testUserSetup = nil
    testDataHelper = nil
    testUser = nil
    testSchoolId = nil
  }

  // MARK: - Navigation Tests

  @MainActor
  func testNavigateToSchoolDetailFromList() async throws {
    // Setup: Create test user and school (use short name to avoid DB varchar limits)
    do {
      testUser = try await testUserSetup.createTestParent()
    } catch {
      throw XCTSkip("Skipping: test user creation failed — \(error.localizedDescription)")
    }
    do {
      testSchoolId = try await testDataHelper.createSchool(
        name: "E2E School",
        userId: testUser!.id,
        familyUnitId: testUser!.familyUnitId
      )
    } catch {
      throw XCTSkip("Skipping: test data creation failed — \(error.localizedDescription)")
    }

    // 1. Login as parent
    app.loginAsParent(email: testUser!.email, password: testUser!.password)
    XCTAssertTrue(app.waitForLogin(timeout: 10), "Should login successfully")

    add(app.takeScreenshot(name: "01-dashboard"))

    // 2. Navigate to Schools List and tap on school
    screen.navigateToSchoolDetailFromDashboard(schoolName: "E2E School")

    // 3. Verify School Detail screen appears
    XCTAssertTrue(screen.waitForSchoolToLoad(timeout: 10),
                  "School Detail should load successfully")

    add(app.takeScreenshot(name: "02-school-detail-loaded"))

    // 4. Verify navigation title
    XCTAssertTrue(screen.navigationTitle.exists,
                  "Navigation title 'School Details' should be visible")

    // 5. Verify favorite button visible
    XCTAssertTrue(screen.favoriteButton.exists,
                  "Favorite button should be visible")

    // 6. Verify status picker visible
    XCTAssertTrue(screen.statusPickerButton.exists,
                  "Status picker button should be visible")

    add(app.takeScreenshot(name: "03-school-detail-elements-verified"))
  }
}
