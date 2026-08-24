import XCTest
@testable import TheRecruitingCompass

final class WidgetVisibilityTests: XCTestCase {

  func testDefault_recruitingPacketEnabled() {
    XCTAssertTrue(WidgetVisibility.default.recruitingPacket)
  }

  func testDecode_missingRecruitingPacketDefaultsTrue() throws {
    // Legacy stored prefs (written before the field existed) omit the key; it must decode as true
    // so the widget is visible by default rather than silently hidden.
    let json = Data(#"{"actionItems": false}"#.utf8)
    let decoded = try JSONDecoder().decode(WidgetVisibility.self, from: json)
    XCTAssertFalse(decoded.actionItems)
    XCTAssertTrue(decoded.recruitingPacket)
  }

  func testDecode_explicitFalseIsHonored() throws {
    let json = Data(#"{"recruitingPacket": false}"#.utf8)
    let decoded = try JSONDecoder().decode(WidgetVisibility.self, from: json)
    XCTAssertFalse(decoded.recruitingPacket)
  }

  func testRoundTrip_preservesRecruitingPacket() throws {
    var visibility = WidgetVisibility.default
    visibility.recruitingPacket = false
    let data = try JSONEncoder().encode(visibility)
    let decoded = try JSONDecoder().decode(WidgetVisibility.self, from: data)
    XCTAssertFalse(decoded.recruitingPacket)
  }
}
