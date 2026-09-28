import XCTest
@testable import TheRecruitingCompass

final class AppInfoTests: XCTestCase {
  func test_clientHeadersIdentifyPlatformVersionAndBuild() {
    let headers = AppInfo.clientHeaders
    XCTAssertEqual(headers["X-Client-Platform"], "ios")
    XCTAssertEqual(headers["X-Client-Version"], AppInfo.version)
    XCTAssertEqual(headers["X-Client-Build"], AppInfo.build)
  }

  func test_addClientHeadersPreservesExistingHeaders() {
    var request = URLRequest(url: URL(string: "https://example.com/api")!)
    request.setValue("Bearer token", forHTTPHeaderField: "Authorization")
    request.addClientHeaders()
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Client-Platform"), "ios")
  }

  func test_currentVersionParses() {
    XCTAssertNotNil(AppVersion(AppInfo.version), "MARKETING_VERSION must stay numeric (e.g. 1.0.1)")
  }

  func test_displayVersionIncludesBuild() {
    XCTAssertEqual(AppInfo.displayVersion, "\(AppInfo.version) (\(AppInfo.build))")
  }

  func test_appStoreURLPointsAtTheApp() {
    XCTAssertEqual(AppInfo.appStoreURL.absoluteString, "https://apps.apple.com/app/id6758562332")
  }
}
