import XCTest

/// Page Object Model for Player Details preference page
/// Provides helper methods for UI test interactions with player profile fields
final class PlayerDetailsScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation Elements

  var navigationTitle: XCUIElement {
    app.navigationBars["Player Details"]
  }

  var saveButton: XCUIElement {
    app.buttons["Save"]
  }

  var backButton: XCUIElement {
    app.navigationBars.buttons.firstMatch
  }

  // MARK: - Read-Only Banner

  var readOnlyBanner: XCUIElement {
    app.staticTexts["Read-Only Mode: Only players can edit their profile"]
  }

  // MARK: - Profile Photo Section

  var profileImageIcon: XCUIElement {
    app.images["person.crop.circle.fill"].firstMatch
  }

  var choosePhotoButton: XCUIElement {
    app.buttons["Choose Photo"]
  }

  var deletePhotoButton: XCUIElement {
    app.buttons["Delete Photo"]
  }

  // MARK: - Basic Information Section

  var graduationYearPicker: XCUIElement {
    app.pickers["Graduation Year"]
  }

  var highSchoolTextField: XCUIElement {
    app.textFields["High School"]
  }

  var clubTeamTextField: XCUIElement {
    app.textFields["Club Team"]
  }

  // MARK: - Athletic Profile Section

  var primarySportTextField: XCUIElement {
    app.textFields["Primary Sport"]
  }

  var primaryPositionTextField: XCUIElement {
    app.textFields["Primary Position"]
  }

  // MARK: - Physical Profile Section

  var batsPicker: XCUIElement {
    app.pickers["Bats"]
  }

  var throwsPicker: XCUIElement {
    app.pickers["Throws"]
  }

  var heightFeetPicker: XCUIElement {
    app.pickers["Height (ft)"]
  }

  var heightInchesPicker: XCUIElement {
    app.pickers["Height (in)"]
  }

  var weightTextField: XCUIElement {
    app.textFields["Weight (lbs)"]
  }

  // MARK: - Academics Section

  var gpaTextField: XCUIElement {
    app.textFields["GPA (0.0-5.0)"]
  }

  var satScoreTextField: XCUIElement {
    app.textFields["SAT Score (400-1600)"]
  }

  var actScoreTextField: XCUIElement {
    app.textFields["ACT Score (1-36)"]
  }

  // MARK: - External Profiles Section

  var ncaaIdTextField: XCUIElement {
    app.textFields["NCAA ID"]
  }

  var perfectGameIdTextField: XCUIElement {
    app.textFields["Perfect Game ID"]
  }

  var prepBaseballIdTextField: XCUIElement {
    app.textFields["Prep Baseball ID"]
  }

  // MARK: - Social Media Section

  var twitterHandleTextField: XCUIElement {
    app.textFields["Twitter (@username)"]
  }

  var instagramHandleTextField: XCUIElement {
    app.textFields["Instagram (@username)"]
  }

  var tiktokHandleTextField: XCUIElement {
    app.textFields["TikTok (@username)"]
  }

  var facebookUrlTextField: XCUIElement {
    app.textFields["Facebook URL"]
  }

  // MARK: - Contact Information Section

  var phoneTextField: XCUIElement {
    app.textFields["Phone"]
  }

  var emailTextField: XCUIElement {
    app.textFields["Email"]
  }

  var allowSharePhoneToggle: XCUIElement {
    app.switches["Allow coaches to see phone"]
  }

  var allowShareEmailToggle: XCUIElement {
    app.switches["Allow coaches to see email"]
  }

  // MARK: - Current High School Section

  var schoolNameTextField: XCUIElement {
    app.textFields["School Name"]
  }

  var schoolAddressTextField: XCUIElement {
    app.textFields["Address"]
  }

  var schoolCityTextField: XCUIElement {
    app.textFields["City"]
  }

  var schoolStateTextField: XCUIElement {
    app.textFields["State (2 letters)"]
  }

  // MARK: - High School Teams (DisclosureGroups)

  func gradeDisclosureGroup(_ grade: String) -> XCUIElement {
    app.buttons["\(grade) Grade Team"]
  }

  func gradeTeamNameTextField(_ grade: String) -> XCUIElement {
    // After expanding disclosure group, find "Team Name" field
    app.textFields["Team Name"]
  }

  func gradeCoachNameTextField(_ grade: String) -> XCUIElement {
    // After expanding disclosure group, find "Coach Name" field
    app.textFields["Coach Name"]
  }

  // MARK: - Travel Team Section

  var travelTeamYearTextField: XCUIElement {
    app.textFields.matching(NSPredicate(format: "placeholderValue == 'Year'")).firstMatch
  }

  var travelTeamNameTextField: XCUIElement {
    // Find "Team Name" in Travel Team section
    app.textFields["Team Name"]
  }

  var travelTeamCoachTextField: XCUIElement {
    // Find "Coach Name" in Travel Team section
    app.textFields["Coach Name"]
  }

  // MARK: - Loading & Error States

  var loadingIndicator: XCUIElement {
    app.staticTexts["Loading details..."]
  }

  var errorAlert: XCUIElement {
    app.alerts["Error"]
  }

  var errorMessage: XCUIElement {
    app.alerts["Error"].staticTexts.element(boundBy: 1)
  }

  var errorOkButton: XCUIElement {
    app.alerts["Error"].buttons["OK"]
  }

  var successMessage: XCUIElement {
    // Success banner appears at top
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'saved'")).firstMatch
  }

  // MARK: - Helper Methods

  func waitForScreenToLoad() -> Bool {
    return navigationTitle.waitForExistence(timeout: 10)
  }

  func isReadOnly() -> Bool {
    return readOnlyBanner.exists
  }

  func isSaveButtonEnabled() -> Bool {
    return saveButton.exists && saveButton.isEnabled
  }

  func scrollToSection(_ sectionName: String) {
    let section = app.staticTexts[sectionName]
    if section.exists {
      section.tap()
    }
  }

  func expandGradeDisclosure(_ grade: String) {
    let disclosure = gradeDisclosureGroup(grade)
    if disclosure.exists && !disclosure.isSelected {
      disclosure.tap()
    }
  }

  // MARK: - Form Filling Methods

  func fillBasicInfo(graduationYear: Int? = nil, highSchool: String? = nil, clubTeam: String? = nil) {
    if let year = graduationYear {
      graduationYearPicker.tap()
      app.pickerWheels.element.adjust(toPickerWheelValue: "\(year)")
    }

    if let school = highSchool {
      highSchoolTextField.tap()
      highSchoolTextField.typeText(school)
    }

    if let club = clubTeam {
      clubTeamTextField.tap()
      clubTeamTextField.typeText(club)
    }
  }

  func fillAthleticProfile(sport: String? = nil, position: String? = nil) {
    if let s = sport {
      primarySportTextField.tap()
      primarySportTextField.typeText(s)
    }

    if let p = position {
      primaryPositionTextField.tap()
      primaryPositionTextField.typeText(p)
    }
  }

  func fillPhysicalProfile(bats: String? = nil, throwingHand: String? = nil, weight: Int? = nil) {
    if let b = bats {
      batsPicker.tap()
      app.pickerWheels.element.adjust(toPickerWheelValue: b)
    }

    if let t = throwingHand {
      throwsPicker.tap()
      app.pickerWheels.element.adjust(toPickerWheelValue: t)
    }

    if let w = weight {
      weightTextField.tap()
      weightTextField.typeText("\(w)")
    }
  }

  func fillAcademics(gpa: Double? = nil, sat: Int? = nil, act: Int? = nil) {
    if let g = gpa {
      gpaTextField.tap()
      gpaTextField.typeText(String(format: "%.2f", g))
    }

    if let s = sat {
      satScoreTextField.tap()
      satScoreTextField.typeText("\(s)")
    }

    if let a = act {
      actScoreTextField.tap()
      actScoreTextField.typeText("\(a)")
    }
  }

  func fillSocialMedia(twitter: String? = nil, instagram: String? = nil) {
    if let tw = twitter {
      twitterHandleTextField.tap()
      twitterHandleTextField.typeText(tw)
    }

    if let ig = instagram {
      instagramHandleTextField.tap()
      instagramHandleTextField.typeText(ig)
    }
  }

  func fillContactInfo(phone: String? = nil, email: String? = nil) {
    if let p = phone {
      phoneTextField.tap()
      phoneTextField.typeText(p)
    }

    if let e = email {
      emailTextField.tap()
      emailTextField.typeText(e)
    }
  }

  func toggleSharePermissions(sharePhone: Bool? = nil, shareEmail: Bool? = nil) {
    if let sp = sharePhone {
      if allowSharePhoneToggle.value as? String != (sp ? "1" : "0") {
        allowSharePhoneToggle.tap()
      }
    }

    if let se = shareEmail {
      if allowShareEmailToggle.value as? String != (se ? "1" : "0") {
        allowShareEmailToggle.tap()
      }
    }
  }

  func tapSave() {
    if saveButton.exists && saveButton.isEnabled {
      saveButton.tap()
    }
  }

  func waitForSaveToComplete(timeout: TimeInterval = 10) -> Bool {
    // Wait for loading indicator to disappear or success message to appear
    let predicate = NSPredicate(format: "exists == false")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: loadingIndicator)
    let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
    return result == .completed
  }

  func dismissKeyboard() {
    // Tap outside text field or use return key
    app.tap()
  }
}
