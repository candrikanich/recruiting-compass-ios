import XCTest

/// Page Object Model for Home Location preference page
final class HomeLocationScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation

  var navigationTitle: XCUIElement {
    app.navigationBars["Home Location"]
  }

  var saveButton: XCUIElement {
    app.buttons["Save"]
  }

  var backButton: XCUIElement {
    app.navigationBars.buttons.element(boundBy: 0)
  }

  // MARK: - Address Fields

  var streetAddressField: XCUIElement {
    app.textFields["Street Address"]
  }

  var cityField: XCUIElement {
    app.textFields["City"]
  }

  var stateField: XCUIElement {
    app.textFields["State"]
  }

  var zipCodeField: XCUIElement {
    app.textFields["ZIP Code"]
  }

  // MARK: - Geocoding

  var lookupFromAddressButton: XCUIElement {
    app.buttons["Lookup from Address"]
  }

  var geocodingProgressIndicator: XCUIElement {
    app.progressIndicators.firstMatch
  }

  var coordinatesReadyIndicator: XCUIElement {
    app.staticTexts["Coordinates Ready"]
  }

  var coordinatesText: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS '°'")).firstMatch
  }

  // MARK: - Coordinate Display

  var latitudeLabel: XCUIElement {
    app.staticTexts["Latitude:"]
  }

  var longitudeLabel: XCUIElement {
    app.staticTexts["Longitude:"]
  }

  func coordinateValue(forLabel label: String) -> String? {
    let labelElement = app.staticTexts[label]
    if labelElement.exists {
      // Find coordinate values displayed near the label
      let coordinateTexts = app.staticTexts.matching(NSPredicate(format: "label MATCHES '[0-9-]+\\\\.[0-9]+'"))
      if coordinateTexts.count > 0 {
        return coordinateTexts.element(boundBy: 0).label
      }
    }
    return nil
  }

  // MARK: - Actions

  var clearLocationButton: XCUIElement {
    app.buttons["Clear Location"]
  }

  // MARK: - States

  var loadingIndicator: XCUIElement {
    app.staticTexts["Loading preferences..."]
  }

  var errorAlert: XCUIElement {
    app.alerts["Error"]
  }

  var geocodingErrorMessage: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'geocoding' OR label CONTAINS[c] 'location'")).firstMatch
  }

  var successMessage: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'saved'")).firstMatch
  }

  // MARK: - Helper Methods

  func waitForScreenToLoad() -> Bool {
    return navigationTitle.waitForExistence(timeout: 10)
  }

  func fillAddress(street: String? = nil, city: String? = nil, state: String? = nil, zip: String? = nil) {
    if let s = street {
      streetAddressField.tap()
      streetAddressField.typeText(s)
    }

    if let c = city {
      cityField.tap()
      cityField.typeText(c)
    }

    if let st = state {
      stateField.tap()
      stateField.typeText(st)
    }

    if let z = zip {
      zipCodeField.tap()
      zipCodeField.typeText(z)
    }
  }

  func tapLookupFromAddress() {
    if lookupFromAddressButton.exists && lookupFromAddressButton.isEnabled {
      lookupFromAddressButton.tap()
    }
  }

  func waitForGeocodingToComplete(timeout: TimeInterval = 15) -> Bool {
    // Wait for progress indicator to disappear or coordinates to appear
    let predicate = NSPredicate(format: "exists == true")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: coordinatesReadyIndicator)
    let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
    return result == .completed
  }

  func hasCoordinates() -> Bool {
    return coordinatesReadyIndicator.exists
  }

  func tapClearLocation() {
    if clearLocationButton.exists {
      clearLocationButton.tap()
    }
  }

  func tapSave() {
    if saveButton.exists && saveButton.isEnabled {
      saveButton.tap()
    }
  }

  func waitForSaveToComplete(timeout: TimeInterval = 10) -> Bool {
    let predicate = NSPredicate(format: "exists == false")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: loadingIndicator)
    let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
    return result == .completed
  }

  func dismissKeyboard() {
    app.tap()
  }
}
