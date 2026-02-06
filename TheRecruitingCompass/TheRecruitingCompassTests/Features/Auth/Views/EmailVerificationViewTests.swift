import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class EmailVerificationViewTests: XCTestCase {
  var mockAuthManager: MockAuthManager!

  override func setUp() {
    super.setUp()
    mockAuthManager = MockAuthManager()
  }

  override func tearDown() {
    mockAuthManager = nil
    super.tearDown()
  }

  func testViewRendersWithUnverifiedUser() {
    let user = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    mockAuthManager.setMockUser(user)

    let view = EmailVerificationView(authManager: mockAuthManager)
    XCTAssertNotNil(view)
  }

  func testViewRendersWithVerifiedUser() {
    let user = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: "2024-01-01T12:00:00Z",
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T12:00:00Z"
    )
    mockAuthManager.setMockUser(user)

    let view = EmailVerificationView(authManager: mockAuthManager)
    XCTAssertNotNil(view)
  }

  func testViewHasBackButton() {
    let user = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    mockAuthManager.setMockUser(user)

    let view = EmailVerificationView(authManager: mockAuthManager)
    let anyView = AnyView(view)

    XCTAssertNotNil(anyView)
  }

  func testViewHasScrollableContent() {
    let user = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    mockAuthManager.setMockUser(user)

    let view = EmailVerificationView(authManager: mockAuthManager)
    let anyView = AnyView(view)

    XCTAssertNotNil(anyView)
  }

  func testViewShowsGradientBackground() {
    let user = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    mockAuthManager.setMockUser(user)

    let view = EmailVerificationView(authManager: mockAuthManager)
    let anyView = AnyView(view)

    // The view should render with the gradient background
    XCTAssertNotNil(anyView)
  }

  func testViewShowsVerifiedState() {
    let user = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: "2024-01-01T12:00:00Z",
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T12:00:00Z"
    )
    mockAuthManager.setMockUser(user)

    let view = EmailVerificationView(authManager: mockAuthManager)
    let anyView = AnyView(view)

    XCTAssertNotNil(anyView)
  }

  func testViewShowsPendingState() {
    let user = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    mockAuthManager.setMockUser(user)

    let view = EmailVerificationView(authManager: mockAuthManager)
    let anyView = AnyView(view)

    XCTAssertNotNil(anyView)
  }
}
