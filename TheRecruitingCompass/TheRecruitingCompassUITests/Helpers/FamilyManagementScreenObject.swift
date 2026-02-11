import XCTest

/// Page Object Model for the Family Management screens (Player and Parent views)
/// Provides helper methods for UI test interactions
final class FamilyManagementScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation Elements

  var navigationTitle: XCUIElement {
    app.navigationBars["Family"]
  }

  var familyTab: XCUIElement {
    app.tabBars.buttons["Family"]
  }

  // MARK: - Player View Elements

  // Family Code Card
  var familyCodeTitle: XCUIElement {
    app.staticTexts["Your Family Code"]
  }

  var familyCodeText: XCUIElement {
    // The code is displayed in a large monospaced font
    app.staticTexts.matching(NSPredicate(format: "label MATCHES 'FAM-[0-9]{6}'")).firstMatch
  }

  var codeCreatedDateText: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Created'")).firstMatch
  }

  var copyButton: XCUIElement {
    app.buttons["Copy"]
  }

  var shareButton: XCUIElement {
    app.buttons["Share"]
  }

  var regenerateButton: XCUIElement {
    app.buttons["Regenerate"]
  }

  var regenerateConfirmButton: XCUIElement {
    app.buttons["Regenerate"]
  }

  var regenerateCancelButton: XCUIElement {
    app.buttons["Cancel"]
  }

  // Family Members Section
  var familyMembersTitle: XCUIElement {
    app.staticTexts["Family Members"]
  }

  var familyMembersCount: XCUIElement {
    // Count appears next to "Family Members" title
    app.staticTexts.matching(NSPredicate(format: "label MATCHES '[0-9]+'")).element(boundBy: 0)
  }

  var emptyMembersIcon: XCUIElement {
    app.images["person.2.slash"]
  }

  var emptyMembersText: XCUIElement {
    app.staticTexts["No family members yet"]
  }

  func memberCard(forName name: String) -> XCUIElement {
    app.staticTexts[name].firstMatch
  }

  func removeMemberButton(forName name: String) -> XCUIElement {
    app.buttons["Remove \(name)"]
  }

  var removeMemberConfirmButton: XCUIElement {
    app.buttons["Remove"]
  }

  var removeMemberCancelButton: XCUIElement {
    app.buttons["Cancel"]
  }

  // MARK: - Parent View Elements

  // Join Family Card
  var joinFamilyTitle: XCUIElement {
    app.staticTexts["Join a Family"]
  }

  var joinFamilyInstructions: XCUIElement {
    app.staticTexts["Enter a family code shared by a player"]
  }

  var familyCodeInput: XCUIElement {
    app.textFields["Enter family code"]
  }

  var joinFamilyButton: XCUIElement {
    app.buttons["Join family button"]
  }

  var joinFamilyLoadingIndicator: XCUIElement {
    app.activityIndicators.firstMatch
  }

  // My Families Section
  var myFamiliesTitle: XCUIElement {
    app.staticTexts["My Families"]
  }

  var myFamiliesCount: XCUIElement {
    // Count appears next to "My Families" title
    app.staticTexts.matching(NSPredicate(format: "label MATCHES '[0-9]+'")).element(boundBy: 1)
  }

  var emptyFamiliesIcon: XCUIElement {
    app.images["person.2.slash"]
  }

  var emptyFamiliesText: XCUIElement {
    app.staticTexts["No families joined yet"]
  }

  func familyCard(forName name: String) -> XCUIElement {
    app.staticTexts[name].firstMatch
  }

  func familyCard(forCode code: String) -> XCUIElement {
    app.staticTexts[code].firstMatch
  }

  // MARK: - Navigation Actions

  /// Navigates to Family Management screen from dashboard
  func navigateToFamilyFromDashboard() {
    if familyTab.waitForExistence(timeout: 5) {
      familyTab.tap()
    }
  }

  func waitForScreenToLoad() -> Bool {
    return navigationTitle.waitForExistence(timeout: 10)
  }

  // MARK: - Player View Actions

  /// Waits for family code to be loaded and visible
  func waitForFamilyCode(timeout: TimeInterval = 10) -> Bool {
    return familyCodeText.waitForExistence(timeout: timeout)
  }

  /// Gets the displayed family code text
  func getFamilyCode() -> String? {
    guard familyCodeText.exists else { return nil }
    return familyCodeText.label
  }

  /// Taps the copy button
  func tapCopyButton() {
    copyButton.tap()
  }

  /// Taps the share button
  func tapShareButton() {
    shareButton.tap()
  }

  /// Initiates code regeneration (opens confirmation dialog)
  func tapRegenerateButton() {
    regenerateButton.tap()
  }

  /// Confirms code regeneration in the dialog
  func confirmRegenerate() {
    if regenerateConfirmButton.waitForExistence(timeout: 5) {
      regenerateConfirmButton.tap()
    }
  }

  /// Cancels code regeneration in the dialog
  func cancelRegenerate() {
    if regenerateCancelButton.waitForExistence(timeout: 5) {
      regenerateCancelButton.tap()
    }
  }

  /// Verifies empty members state is visible
  func verifyEmptyMembersState() -> Bool {
    return emptyMembersIcon.exists && emptyMembersText.exists
  }

  /// Taps remove button for a specific member
  func tapRemoveMember(name: String) {
    let removeButton = removeMemberButton(forName: name)
    if removeButton.waitForExistence(timeout: 5) {
      removeButton.tap()
    }
  }

  /// Confirms member removal in the dialog
  func confirmRemoveMember() {
    if removeMemberConfirmButton.waitForExistence(timeout: 5) {
      removeMemberConfirmButton.tap()
    }
  }

  /// Cancels member removal in the dialog
  func cancelRemoveMember() {
    if removeMemberCancelButton.waitForExistence(timeout: 5) {
      removeMemberCancelButton.tap()
    }
  }

  // MARK: - Parent View Actions

  /// Enters a family code in the input field
  func enterFamilyCode(_ code: String) {
    familyCodeInput.tap()
    familyCodeInput.typeText(code)
  }

  /// Clears the family code input field
  func clearFamilyCodeInput() {
    familyCodeInput.tap()

    if let currentValue = familyCodeInput.value as? String, !currentValue.isEmpty {
      let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
      familyCodeInput.typeText(deleteString)
    }
  }

  /// Taps the join family button
  func tapJoinFamily() {
    joinFamilyButton.tap()
  }

  /// Waits for join family operation to complete
  func waitForJoinToComplete(timeout: TimeInterval = 15) -> Bool {
    // Wait for loading indicator to disappear
    let loadingGone = !joinFamilyLoadingIndicator.exists ||
                      !joinFamilyLoadingIndicator.waitForExistence(timeout: 1)

    if !loadingGone {
      // Loading appeared, wait for it to disappear
      let predicate = NSPredicate(format: "exists == false")
      let expectation = XCTNSPredicateExpectation(predicate: predicate, object: joinFamilyLoadingIndicator)
      let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
      return result == .completed
    }

    return true
  }

  /// Verifies empty families state is visible
  func verifyEmptyFamiliesState() -> Bool {
    return emptyFamiliesIcon.exists && emptyFamiliesText.exists
  }

  /// Verifies join button is enabled
  func verifyJoinButtonEnabled() -> Bool {
    return joinFamilyButton.isEnabled
  }

  /// Verifies join button is disabled
  func verifyJoinButtonDisabled() -> Bool {
    return !joinFamilyButton.isEnabled
  }

  /// Gets the number of families in the list
  func getFamiliesCount() -> Int {
    // Count family cards by looking for family name text elements
    // This is a simplified approach - adjust based on actual implementation
    if emptyFamiliesText.exists {
      return 0
    }
    // Note: This may need adjustment based on actual UI structure
    return app.staticTexts.matching(NSPredicate(format: "label MATCHES 'FAM-[0-9]{6}'")).count
  }
}
