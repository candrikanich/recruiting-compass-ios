import XCTest
@testable import TheRecruitingCompass

#if DEBUG
final class CaptchaBypassPolicyTests: XCTestCase {
  private func shouldBypass(
    _ arguments: [String],
    host: String?,
    isUITestBackendOverride: Bool = false
  ) -> Bool {
    CaptchaBypassPolicy.shouldBypass(
      arguments: arguments,
      supabaseHost: host,
      isUITestBackendOverride: isUITestBackendOverride
    )
  }

  func test_noFlag_neverBypasses() {
    XCTAssertFalse(shouldBypass([], host: "127.0.0.1", isUITestBackendOverride: true))
    XCTAssertFalse(shouldBypass(["--uitesting"], host: "e2e.supabase.co", isUITestBackendOverride: true))
  }

  func test_localFlag_bypassesOnLoopbackHostsOnly() {
    XCTAssertTrue(shouldBypass(["--local-captcha-bypass"], host: "127.0.0.1"))
    XCTAssertTrue(shouldBypass(["--local-captcha-bypass"], host: "localhost"))
    XCTAssertFalse(shouldBypass(["--local-captcha-bypass"], host: "e2e.supabase.co", isUITestBackendOverride: true))
    XCTAssertFalse(shouldBypass(["--local-captcha-bypass"], host: nil))
  }

  func test_e2eFlag_bypassesOnlyWhenUITestsSuppliedTheBackend() {
    XCTAssertTrue(shouldBypass(["--e2e-captcha-bypass"], host: "e2e.supabase.co", isUITestBackendOverride: true))
    XCTAssertFalse(shouldBypass(["--e2e-captcha-bypass"], host: "prod.supabase.co", isUITestBackendOverride: false))
  }
}
#endif
