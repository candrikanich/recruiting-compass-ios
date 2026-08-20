import SwiftUI
import XCTest
@testable import TheRecruitingCompass

final class CommunicationButtonTests: XCTestCase {

  // MARK: - Call Type Tests

  func testCallType_URLGeneration() {
    let type = CommunicationType.call("555-1234")
    let url = type.url(for: "555-1234")

    XCTAssertNotNil(url)
    XCTAssertEqual(url?.absoluteString, "tel:5551234")
  }

  func testCallType_IconName() {
    let type = CommunicationType.call("555-1234")
    XCTAssertEqual(type.iconName, "phone.fill")
  }

  func testCallType_IconColor() {
    let type = CommunicationType.call("555-1234")
    XCTAssertEqual(type.iconColor, Color.Brand.purple600)
  }

  func testCallType_AccessibilityLabel() {
    let type = CommunicationType.call("555-1234")
    XCTAssertEqual(type.accessibilityLabel, "Call coach")
  }

  func testCallType_AppName() {
    let type = CommunicationType.call("555-1234")
    XCTAssertEqual(type.appName, "Phone")
  }

  // MARK: - Edge Cases

  func testCallType_EmptyPhoneNumber() {
    let type = CommunicationType.call("")
    let url = type.url(for: "")

    XCTAssertNil(url, "Empty phone number should return nil URL")
  }

  func testCallType_WhitespaceOnly() {
    let type = CommunicationType.call("   ")
    let url = type.url(for: "   ")

    XCTAssertNil(url, "Whitespace-only phone number should return nil URL")
  }

  func testCallType_PhoneNumberWithSpaces() {
    let type = CommunicationType.call("555 123 4567")
    let url = type.url(for: "555 123 4567")

    XCTAssertNotNil(url)
    XCTAssertEqual(url?.absoluteString, "tel:5551234567")
  }

  func testCallType_PhoneNumberWithDashes() {
    let type = CommunicationType.call("555-123-4567")
    let url = type.url(for: "555-123-4567")

    XCTAssertNotNil(url)
    XCTAssertEqual(url?.absoluteString, "tel:5551234567")
  }

  func testCallType_PhoneNumberWithParentheses() {
    let type = CommunicationType.call("(555) 123-4567")
    let url = type.url(for: "(555) 123-4567")

    XCTAssertNotNil(url)
    XCTAssertEqual(url?.absoluteString, "tel:5551234567")
  }

  // MARK: - SMS Type Comparison (Ensure no regression)

  func testSMSType_StillWorksCorrectly() {
    let type = CommunicationType.phone("555-1234")
    let url = type.url(for: "555-1234")

    XCTAssertNotNil(url)
    XCTAssertEqual(url?.absoluteString, "sms:5551234")
    XCTAssertEqual(type.iconName, "message.fill")
    XCTAssertEqual(type.accessibilityLabel, "Text coach")
  }

  // MARK: - Email Type Comparison (Ensure no regression)

  func testEmailType_StillWorksCorrectly() {
    let type = CommunicationType.email("test@example.com")
    let url = type.url(for: "test@example.com")

    XCTAssertNotNil(url)
    XCTAssertEqual(url?.absoluteString, "mailto:test@example.com")
    XCTAssertEqual(type.iconName, "envelope.fill")
    XCTAssertEqual(type.accessibilityLabel, "Email coach")
  }
}
