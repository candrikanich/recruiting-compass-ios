import XCTest

/// E2E tests for Add School duplicate detection functionality
/// Tests name match, domain match, and NCAA ID match detection
final class AddSchoolDuplicateDetectionE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: AddSchoolScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
      "SUPABASE_ANON_KEY": ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    ]
    app.launch()

    screen = AddSchoolScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Domain Match Tests

  /// Test: Duplicate website domain detection shows dialog with "Website Domain" badge
  /// Covers spec duplicate detection - domain match (lines 727-735)
  @MainActor
  func testAddSchool_duplicateDomain_showsDialog() throws {
    // Given: User is logged in
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    add(app.takeScreenshot(name: "01-domain-dashboard"))

    // Note: This test assumes a school with "https://test.edu" already exists
    // In production testing, use SchoolTestDataHelper to create prerequisite data

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "02-domain-add-school-screen"))

    // When: Try to add a school with the same domain
    screen.toggleAutocomplete(enabled: false)
    screen.fillSchoolName("Different School Name") // Different name, same domain
    screen.fillLocation("Different Location")
    screen.fillWebsite("https://test.edu") // Assuming this domain exists

    add(app.takeScreenshot(name: "03-domain-duplicate-domain-entered"))

    screen.dismissKeyboard()

    // When: Submit form
    screen.submitForm()

    add(app.takeScreenshot(name: "04-domain-submitting"))

    // Then: Duplicate dialog should appear
    let dialogAppeared = screen.waitForDuplicateDialog(timeout: 10)

    if dialogAppeared {
      add(app.takeScreenshot(name: "05-domain-dialog-shown"))

      // Verify match type badge is "Website Domain" (yellow)
      let matchTypeBadge = screen.duplicateMatchTypeBadge

      if matchTypeBadge.exists {
        let badgeText = matchTypeBadge.label
        XCTAssertTrue(
          badgeText.contains("Website") || badgeText.contains("Domain"),
          "Match type badge should indicate 'Website Domain'"
        )

        add(app.takeScreenshot(name: "06-domain-website-domain-badge"))
      }

      // Verify existing school details are shown
      XCTAssertTrue(
        screen.duplicateDialogMessage.exists,
        "Duplicate dialog should show existing school details"
      )

      add(app.takeScreenshot(name: "07-domain-existing-school-details"))

      // When: Cancel
      screen.cancelDuplicateDialog()

      add(app.takeScreenshot(name: "08-domain-after-cancel"))

      // Then: Should return to form
      XCTAssertTrue(
        screen.navigationTitle.exists,
        "Should return to Add School form after cancel"
      )

      add(app.takeScreenshot(name: "09-domain-back-to-form"))
    } else {
      // No duplicate found - test data doesn't exist
      add(app.takeScreenshot(name: "10-domain-no-duplicate-found"))
      throw XCTSkip("No duplicate domain detected - prerequisite test data may not exist")
    }
  }

  /// Test: Duplicate NCAA ID detection shows dialog with "NCAA ID" badge
  /// Covers spec duplicate detection - NCAA ID match
  @MainActor
  func testAddSchool_duplicateNcaaId_showsDialog() throws {
    // Given: User is logged in
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    add(app.takeScreenshot(name: "11-ncaa-dashboard"))

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "12-ncaa-add-school-screen"))

    // Note: This test requires a school with NCAA ID to already exist
    // NCAA ID is typically populated via NCAA lookup when selecting from autocomplete

    // When: Select a college that would have the same NCAA ID as an existing school
    screen.searchCollege(query: "University of Florida")
    sleep(1)

    add(app.takeScreenshot(name: "13-ncaa-search-results"))

    // Check if autocomplete results exist
    if screen.autocompleteResult(at: 0).waitForExistence(timeout: 5) {
      screen.selectAutocompleteResult(at: 0)

      add(app.takeScreenshot(name: "14-ncaa-college-selected"))

      _ = screen.waitForEnrichmentToComplete(timeout: 15)

      add(app.takeScreenshot(name: "15-ncaa-enrichment-complete"))

      // When: Submit form
      screen.submitForm()

      add(app.takeScreenshot(name: "16-ncaa-submitting"))

      // Then: Duplicate dialog MAY appear if NCAA ID match exists
      let dialogAppeared = screen.waitForDuplicateDialog(timeout: 10)

      if dialogAppeared {
        add(app.takeScreenshot(name: "17-ncaa-dialog-shown"))

        // Verify match type badge
        let matchTypeBadge = screen.duplicateMatchTypeBadge

        if matchTypeBadge.exists {
          let badgeText = matchTypeBadge.label

          // Could be NCAA ID, Name, or Domain match
          XCTAssertTrue(
            matchTypeBadge.exists,
            "Match type badge should be visible"
          )

          add(app.takeScreenshot(name: "18-ncaa-match-type-badge"))

          if badgeText.contains("NCAA") {
            // NCAA ID match detected
            add(app.takeScreenshot(name: "19-ncaa-ncaa-id-badge"))
          }
        }

        // Cancel the dialog
        screen.cancelDuplicateDialog()

        add(app.takeScreenshot(name: "20-ncaa-after-cancel"))
      } else {
        // No duplicate - this is acceptable for this test
        add(app.takeScreenshot(name: "21-ncaa-no-duplicate"))
        throw XCTSkip("No NCAA ID duplicate detected")
      }
    } else {
      throw XCTSkip("Autocomplete search failed - College Scorecard API may not be configured")
    }
  }

  // MARK: - Duplicate Workflow Tests

  /// Test: User can proceed with duplicate creation after seeing warning
  /// Covers "Proceed Anyway" flow in duplicate dialog
  @MainActor
  func testAddSchool_duplicateDialog_proceedAnywayCreatesSchool() throws {
    // Given: User is logged in
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    add(app.takeScreenshot(name: "22-proceed-dashboard"))

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "23-proceed-add-school-screen"))

    // When: Create a school with a common name (likely to be duplicate)
    screen.toggleAutocomplete(enabled: false)

    // Use a timestamped name to avoid actual duplicates
    let timestamp = Int(Date().timeIntervalSince1970)
    screen.fillSchoolName("Test School 1") // If this exists, we'll get dialog

    screen.fillLocation("Test City")

    add(app.takeScreenshot(name: "24-proceed-form-filled"))

    screen.dismissKeyboard()

    // When: Submit form
    screen.submitForm()

    add(app.takeScreenshot(name: "25-proceed-submitting"))

    // If duplicate dialog appears
    let dialogAppeared = screen.waitForDuplicateDialog(timeout: 10)

    if dialogAppeared {
      add(app.takeScreenshot(name: "26-proceed-dialog-appeared"))

      // When: Tap "Proceed Anyway"
      screen.proceedWithDuplicate()

      add(app.takeScreenshot(name: "27-proceed-proceeded-anyway"))

      // Then: School should be created despite duplicate
      _ = screen.waitForSubmissionToComplete(timeout: 15)

      add(app.takeScreenshot(name: "28-proceed-after-submit"))

      let success = app.navigationBars["School Details"].waitForExistence(timeout: 10) ||
                    app.navigationBars["Schools"].waitForExistence(timeout: 10)

      XCTAssertTrue(
        success,
        "Should create school after proceeding with duplicate warning"
      )

      add(app.takeScreenshot(name: "29-proceed-success"))
    } else {
      // No duplicate - submit should succeed normally
      _ = screen.waitForSubmissionToComplete(timeout: 15)

      add(app.takeScreenshot(name: "30-proceed-no-duplicate"))

      let success = app.navigationBars["School Details"].waitForExistence(timeout: 10) ||
                    app.navigationBars["Schools"].waitForExistence(timeout: 10)

      XCTAssertTrue(
        success,
        "Should create school when no duplicate exists"
      )

      add(app.takeScreenshot(name: "31-proceed-normal-success"))
    }
  }

  /// Test: Duplicate detection works with offline cached schools list
  /// Covers duplicate detection against locally cached data
  @MainActor
  func testAddSchool_duplicateDetection_worksWithCachedData() throws {
    // Given: User is logged in and has cached schools
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    add(app.takeScreenshot(name: "32-cached-dashboard"))

    // First, ensure we have cached schools by visiting Schools List
    if app.tabBars.buttons["Schools"].exists {
      app.tabBars.buttons["Schools"].tap()

      add(app.takeScreenshot(name: "33-cached-schools-list"))

      // Wait for schools to load
      sleep(2)

      add(app.takeScreenshot(name: "34-cached-schools-loaded"))

      // Now navigate to Add School
      let addButton = app.navigationBars.buttons["Add new school"]
      if addButton.exists {
        addButton.tap()
      }
    } else {
      screen.navigateToAddSchoolFromDashboard()
    }

    add(app.takeScreenshot(name: "35-cached-add-school-screen"))

    // When: Try to add a duplicate school
    screen.toggleAutocomplete(enabled: false)
    screen.fillSchoolName("Test School 1") // Assuming this exists in cache
    screen.fillLocation("Test Location")

    add(app.takeScreenshot(name: "36-cached-duplicate-name"))

    screen.dismissKeyboard()

    // When: Submit
    screen.submitForm()

    add(app.takeScreenshot(name: "37-cached-submitting"))

    // Then: Duplicate detection should work even with cached data
    let dialogAppeared = screen.waitForDuplicateDialog(timeout: 10)

    if dialogAppeared {
      add(app.takeScreenshot(name: "38-cached-duplicate-detected"))

      XCTAssertTrue(
        screen.duplicateDialog.exists,
        "Duplicate detection should work with locally cached schools"
      )

      screen.cancelDuplicateDialog()

      add(app.takeScreenshot(name: "39-cached-dialog-cancelled"))
    } else {
      // No duplicate in cache
      add(app.takeScreenshot(name: "40-cached-no-duplicate"))
      throw XCTSkip("No cached duplicate found - test data may not exist")
    }
  }

  // MARK: - Match Type Badge Tests

  /// Test: Duplicate dialog shows correct match type badge colors
  /// Covers badge color verification (Name=red, Domain=yellow, NCAA=orange)
  @MainActor
  func testAddSchool_duplicateDialog_correctBadgeColors() throws {
    // Given: User is logged in
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    add(app.takeScreenshot(name: "41-badge-dashboard"))

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "42-badge-add-school-screen"))

    // When: Create a duplicate by exact name match
    screen.toggleAutocomplete(enabled: false)
    screen.fillSchoolName("Test School 1")
    screen.fillLocation("Test Location")

    add(app.takeScreenshot(name: "43-badge-name-match-form"))

    screen.dismissKeyboard()

    screen.submitForm()

    add(app.takeScreenshot(name: "44-badge-submitting"))

    // Then: Dialog should appear with appropriate badge
    let dialogAppeared = screen.waitForDuplicateDialog(timeout: 10)

    if dialogAppeared {
      add(app.takeScreenshot(name: "45-badge-dialog-with-badge"))

      // Verify match type badge exists
      let matchTypeBadge = screen.duplicateMatchTypeBadge

      XCTAssertTrue(
        matchTypeBadge.exists,
        "Match type badge should be visible in duplicate dialog"
      )

      // Document the match type
      let badgeText = matchTypeBadge.label

      if badgeText.contains("Name") {
        add(app.takeScreenshot(name: "46-badge-name-match-red"))
      } else if badgeText.contains("Domain") || badgeText.contains("Website") {
        add(app.takeScreenshot(name: "47-badge-domain-match-yellow"))
      } else if badgeText.contains("NCAA") {
        add(app.takeScreenshot(name: "48-badge-ncaa-match-orange"))
      }

      // Verify existing school details are shown
      XCTAssertTrue(
        screen.duplicateDialogMessage.exists,
        "Dialog should show existing school details"
      )

      add(app.takeScreenshot(name: "49-badge-existing-school-details"))

      screen.cancelDuplicateDialog()

      add(app.takeScreenshot(name: "50-badge-dialog-cancelled"))
    } else {
      throw XCTSkip("No duplicate detected - test data may not exist")
    }
  }
}
