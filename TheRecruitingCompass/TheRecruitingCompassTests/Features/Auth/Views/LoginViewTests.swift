import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class LoginViewTests: XCTestCase {
  func testLoginViewRendersEmailField() {
    let view = LoginView()
      .environmentObject(AuthManager.shared)

    XCTAssertNotNil(view)
  }
}
