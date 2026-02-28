import XCTest

enum TestUserRole: String {
  case parent = "Parent"
  case player = "Player"
}

struct TestUserData {
  let fullName: String
  let email: String
  let password: String
  let role: TestUserRole
  let familyCode: String?

  static func uniqueParent(familyCode: String? = nil) -> TestUserData {
    let timestamp = Int(Date().timeIntervalSince1970)
    return TestUserData(
      fullName: "Test Parent",
      email: "testparent+\(timestamp)@example.com",
      password: "StrongPass1",
      role: .parent,
      familyCode: familyCode
    )
  }

  static func uniquePlayer(familyCode: String? = nil) -> TestUserData {
    let timestamp = Int(Date().timeIntervalSince1970)
    return TestUserData(
      fullName: "Test Player",
      email: "testplayer+\(timestamp)@example.com",
      password: "StrongPass1",
      role: .player,
      familyCode: familyCode
    )
  }
}

extension XCUIApplication {
  func waitForElement(
    _ element: XCUIElement,
    timeout: TimeInterval = 10,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let predicate = NSPredicate(format: "exists == true")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
    let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
    XCTAssertEqual(result, .completed, "Element \(element) not found within \(timeout)s", file: file, line: line)
  }

  func waitForElementToDisappear(
    _ element: XCUIElement,
    timeout: TimeInterval = 10,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let predicate = NSPredicate(format: "exists == false")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
    let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
    XCTAssertEqual(result, .completed, "Element \(element) still exists after \(timeout)s", file: file, line: line)
  }

  func takeScreenshot(name: String, lifetime: XCTAttachment.Lifetime = .keepAlways) -> XCTAttachment {
    let screenshot = self.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = lifetime
    return attachment
  }
}

extension XCUIElement {
  func clearAndTypeText(_ text: String) {
    guard exists else { return }
    tap()

    if let currentValue = value as? String, !currentValue.isEmpty {
      let selectAll = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
      typeText(selectAll)
    }

    typeText(text)
  }

  func waitAndTap(timeout: TimeInterval = 10) {
    let predicate = NSPredicate(format: "isHittable == true")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
    let result = XCTWaiter.wait(for: [expectation], timeout: timeout)

    if result == .completed {
      tap()
    }
  }
}

// MARK: - Authentication Helpers

extension XCUIApplication {

  /// Logs in as a parent user with the provided credentials
  /// Assumes app is on landing screen
  /// - Parameters:
  ///   - email: Parent email
  ///   - password: Parent password
  func loginAsParent(email: String, password: String) {
    // Tap "Sign In" button on landing
    let signInButton = buttons["Sign in to your account"]
    if signInButton.waitForExistence(timeout: 5) {
      signInButton.tap()
    }

    // Fill in email and password
    let emailField = textFields["Email"]
    if emailField.waitForExistence(timeout: 5) {
      emailField.tap()
      emailField.typeText(email)
    }

    let passwordField = secureTextFields["Password"]
    if passwordField.exists {
      passwordField.tap()
      passwordField.typeText(password)
    }

    // Tap Sign In button
    let submitButton = buttons["Sign in"]
    if submitButton.exists {
      submitButton.tap()
    }

    // Wait for dashboard to appear
    let dashboardTitle = navigationBars["Dashboard"]
    _ = dashboardTitle.waitForExistence(timeout: 10)
  }

  /// Logs in as a player user with the provided credentials
  /// - Parameters:
  ///   - email: Player email
  ///   - password: Player password
  func loginAsPlayer(email: String, password: String) {
    // Same flow as parent (login UI is the same)
    loginAsParent(email: email, password: password)
  }

  /// Logs in with test user data
  /// - Parameter userData: Test user data including email and password
  func login(with userData: TestUserData) {
    loginAsParent(email: userData.email, password: userData.password)
  }

  /// Logs out the current user
  /// Assumes user is logged in and can access profile/settings
  func logout() {
    // Navigate to profile/settings tab
    if tabBars.buttons["Profile"].exists {
      tabBars.buttons["Profile"].tap()
    }

    // Tap logout button (adjust selector based on actual UI)
    let logoutButton = buttons["Log out"]
    if logoutButton.waitForExistence(timeout: 5) {
      logoutButton.tap()
    }

    // Confirm logout if there's a confirmation dialog
    if alerts.buttons["Log out"].exists {
      alerts.buttons["Log out"].tap()
    }

    // Wait for landing screen to appear
    let createAccountButton = buttons["Create a new account"]
    _ = createAccountButton.waitForExistence(timeout: 10)
  }

  /// Waits for the user to be logged in (dashboard visible)
  /// - Parameter timeout: Timeout in seconds
  /// - Returns: True if dashboard appeared, false otherwise
  func waitForLogin(timeout: TimeInterval = 10) -> Bool {
    let dashboardTitle = navigationBars["Dashboard"]
    return dashboardTitle.waitForExistence(timeout: timeout)
  }
}
