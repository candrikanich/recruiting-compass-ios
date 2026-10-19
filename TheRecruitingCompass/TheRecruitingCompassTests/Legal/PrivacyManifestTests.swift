import XCTest
@testable import TheRecruitingCompass

/// Guards the bundled privacy manifest against drifting from the App Store Connect label.
final class PrivacyManifestTests: XCTestCase {
  private typealias Entry = [String: Any]

  private func manifest() throws -> [String: Any] {
    let bundle = Bundle(for: AppDelegate.self)
    let url = try XCTUnwrap(bundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
    let data = try Data(contentsOf: url)
    return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
  }

  private func collectedTypes() throws -> [Entry] {
    try XCTUnwrap(manifest()["NSPrivacyCollectedDataTypes"] as? [Entry])
  }

  func test_emailAddress_declaresAppFunctionalityAnalyticsAndDeveloperAdvertising() throws {
    let email = try XCTUnwrap(
      collectedTypes().first {
        $0["NSPrivacyCollectedDataType"] as? String == "NSPrivacyCollectedDataTypeEmailAddress"
      })
    let purposes = Set(try XCTUnwrap(email["NSPrivacyCollectedDataTypePurposes"] as? [String]))
    XCTAssertEqual(purposes, [
      "NSPrivacyCollectedDataTypePurposeAppFunctionality",
      "NSPrivacyCollectedDataTypePurposeAnalytics",
      "NSPrivacyCollectedDataTypePurposeDeveloperAdvertising"
    ])
  }

  func test_noEntryIsUsedForTracking() throws {
    XCTAssertEqual(try manifest()["NSPrivacyTracking"] as? Bool, false)
    for entry in try collectedTypes() {
      XCTAssertEqual(entry["NSPrivacyCollectedDataTypeTracking"] as? Bool, false, "\(entry)")
    }
  }
}
