import XCTest

enum TestUserRole: String {
  case parent = "Parent"
  case student = "Student"
  case player = "Player"
}

struct TestUserData {
  let fullName: String
  let email: String
  let password: String
  let role: TestUserRole
  let familyCode: String?

  static func uniqueParent() -> TestUserData {
    let timestamp = Int(Date().timeIntervalSince1970)
    return TestUserData(
      fullName: "Test Parent",
      email: "testparent+\(timestamp)@example.com",
      password: "StrongPass1",
      role: .parent,
      familyCode: nil
    )
  }

  static func uniqueStudent(familyCode: String? = nil) -> TestUserData {
    let timestamp = Int(Date().timeIntervalSince1970)
    return TestUserData(
      fullName: "Test Student",
      email: "teststudent+\(timestamp)@example.com",
      password: "StrongPass1",
      role: .student,
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
