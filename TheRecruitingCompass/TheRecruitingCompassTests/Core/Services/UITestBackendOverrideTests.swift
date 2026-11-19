import XCTest
@testable import TheRecruitingCompass

final class UITestBackendOverrideTests: XCTestCase {
  private func resolve(isUITesting: Bool, _ environment: [String: String]) -> UITestBackendOverride {
    UITestBackendOverride.resolve("SUPABASE_URL", isUITesting: isUITesting, environment: environment)
  }

  func test_uiTesting_missingValue_failsClosedInsteadOfFallingBackToEmbeddedConfig() {
    XCTAssertEqual(resolve(isUITesting: true, [:]), .missing)
  }

  func test_uiTesting_emptyOrBlankValue_failsClosed() {
    XCTAssertEqual(resolve(isUITesting: true, ["SUPABASE_URL": ""]), .missing)
    XCTAssertEqual(resolve(isUITesting: true, ["SUPABASE_URL": "   "]), .missing)
  }

  func test_uiTesting_suppliedValue_isUsed() {
    XCTAssertEqual(
      resolve(isUITesting: true, ["SUPABASE_URL": "http://127.0.0.1:54321"]),
      .value("http://127.0.0.1:54321")
    )
  }

  func test_normalLaunch_isUntouchedWhetherOrNotTheValueIsSet() {
    XCTAssertEqual(resolve(isUITesting: false, [:]), .inactive)
    XCTAssertEqual(resolve(isUITesting: false, ["SUPABASE_URL": "http://127.0.0.1:54321"]), .inactive)
  }

  func test_blankValueWithNewlines_failsClosed() {
    XCTAssertEqual(resolve(isUITesting: true, ["SUPABASE_URL": " \n\t "]), .missing)
  }

  // MARK: - requiredSetting (SUPABASE_URL / SUPABASE_ANON_KEY decision)

  private typealias Outcome = (Result<String, UITestBackendOverride.MissingSetting>, otherwiseCalled: Bool)

  private func required(_ key: String, isUITesting: Bool, _ env: [String: String]) -> Outcome {
    var called = false
    let result = UITestBackendOverride.requiredSetting(key, isUITesting: isUITesting, environment: env) {
      called = true
      return "embedded-prod"
    }
    return (result, called)
  }

  func test_requiredSetting_uiTestingMissing_failsAndNeverConsultsEmbedded() {
    for key in ["SUPABASE_URL", "SUPABASE_ANON_KEY"] {
      let outcome = required(key, isUITesting: true, [key: "  "])
      XCTAssertEqual(outcome.0, .failure(.init(key: key)), key)
      XCTAssertFalse(outcome.otherwiseCalled, "\(key) consulted the embedded source under --uitesting")
    }
  }

  func test_requiredSetting_uiTestingSupplied_usesEnvironmentValue() {
    let outcome = required("SUPABASE_ANON_KEY", isUITesting: true, ["SUPABASE_ANON_KEY": "local-key"])
    XCTAssertEqual(outcome.0, .success("local-key"))
    XCTAssertFalse(outcome.otherwiseCalled)
  }

  func test_requiredSetting_normalLaunch_usesNormalSource() {
    let outcome = required("SUPABASE_URL", isUITesting: false, [:])
    XCTAssertEqual(outcome.0, .success("embedded-prod"))
    XCTAssertTrue(outcome.otherwiseCalled)
  }

  // MARK: - apiBaseURL

  private func api(isUITesting: Bool, _ env: [String: String], embedded: String = "https://prod.example.com") -> URL? {
    UITestBackendOverride.apiBaseURL(
      isUITesting: isUITesting, environment: env, embedded: embedded, releaseFallback: "https://release.example.com"
    )
  }

  func test_apiBaseURL_uiTestingWithoutValue_isNilEvenWhenEmbeddedIsProd() {
    XCTAssertNil(api(isUITesting: true, [:]))
    XCTAssertNil(api(isUITesting: true, ["API_BASE_URL": " "]))
  }

  func test_apiBaseURL_uiTestingPlaceholderValue_neverSwapsInEmbeddedProd() {
    let url = api(isUITesting: true, ["API_BASE_URL": "http://placeholder.local"])
    XCTAssertEqual(url?.absoluteString, "http://placeholder.local")
  }

  func test_apiBaseURL_uiTestingSupplied_usesIt() {
    let url = api(isUITesting: true, ["API_BASE_URL": "http://localhost:3003"])
    XCTAssertEqual(url?.absoluteString, "http://localhost:3003")
  }

  func test_apiBaseURL_normalLaunch_keepsEnvThenEmbeddedThenReleaseFallbackOrder() {
    XCTAssertEqual(api(isUITesting: false, ["API_BASE_URL": "http://env.local"])?.absoluteString, "http://env.local")
    XCTAssertEqual(api(isUITesting: false, [:])?.absoluteString, "https://prod.example.com")
    let placeholderEnv = ["API_BASE_URL": "placeholder"]
    XCTAssertEqual(api(isUITesting: false, placeholderEnv, embedded: "")?.absoluteString, "https://release.example.com")
    XCTAssertNil(UITestBackendOverride.apiBaseURL(
      isUITesting: false, environment: [:], embedded: "", releaseFallback: ""
    ))
    XCTAssertEqual(api(isUITesting: false, ["API_BASE_URL": "example.com"])?.absoluteString, "https://example.com")
  }

  // MARK: - SupabaseConfig wiring (arguments + environment -> resolved values)

  #if DEBUG
  private let uiTestArgs = ["myCompass", "--uitesting"]

  func test_resolvedURL_uiTestingWithoutEnvironment_failsClosed() {
    XCTAssertEqual(SupabaseConfig.resolvedURL(arguments: uiTestArgs, environment: [:]),
                   .failure(.init(key: "SUPABASE_URL")))
    XCTAssertEqual(SupabaseConfig.resolvedURL(arguments: uiTestArgs, environment: ["SUPABASE_ANON_KEY": "k"]),
                   .failure(.init(key: "SUPABASE_URL")))
  }

  func test_resolvedURL_uiTestingWithEnvironment_usesIt() {
    XCTAssertEqual(
      SupabaseConfig.resolvedURL(arguments: uiTestArgs, environment: ["SUPABASE_URL": "http://127.0.0.1:54321"]),
      .success("http://127.0.0.1:54321")
    )
  }

  func test_resolvedAnonKey_uiTestingWithoutItsOwnKey_failsClosedEvenWhenURLIsSet() {
    XCTAssertEqual(SupabaseConfig.resolvedAnonKey(arguments: uiTestArgs, environment: [:]),
                   .failure(.init(key: "SUPABASE_ANON_KEY")))
    XCTAssertEqual(SupabaseConfig.resolvedAnonKey(arguments: uiTestArgs, environment: ["SUPABASE_URL": "http://x"]),
                   .failure(.init(key: "SUPABASE_ANON_KEY")))
  }

  func test_resolvedAnonKey_uiTestingWithEnvironment_usesIt() {
    XCTAssertEqual(
      SupabaseConfig.resolvedAnonKey(arguments: uiTestArgs, environment: ["SUPABASE_ANON_KEY": "local-key"]),
      .success("local-key")
    )
  }

  func test_resolvedAPIBaseURL_uiTestingWithoutEnvironment_isNilEvenWhenEmbeddedIsProd() {
    XCTAssertNil(SupabaseConfig.resolvedAPIBaseURL(
      arguments: uiTestArgs, environment: [:], embedded: "https://prod.example.com"
    ))
  }

  func test_resolvedAPIBaseURL_withoutUITestingFlag_fallsBackToEmbedded() {
    let url = SupabaseConfig.resolvedAPIBaseURL(
      arguments: ["myCompass"], environment: [:], embedded: "https://prod.example.com"
    )
    XCTAssertEqual(url?.absoluteString, "https://prod.example.com")
  }

  func test_isUITestBackendOverride_trueOnlyWhenUITestingSuppliedTheURL() {
    let url = ["SUPABASE_URL": "http://127.0.0.1:54321"]
    XCTAssertTrue(SupabaseConfig.resolvedIsUITestBackendOverride(arguments: uiTestArgs, environment: url))
    XCTAssertFalse(SupabaseConfig.resolvedIsUITestBackendOverride(arguments: uiTestArgs, environment: [:]))
    let blank = ["SUPABASE_URL": " \n"]
    XCTAssertFalse(SupabaseConfig.resolvedIsUITestBackendOverride(arguments: uiTestArgs, environment: blank))
    XCTAssertFalse(SupabaseConfig.resolvedIsUITestBackendOverride(arguments: ["myCompass"], environment: url))
  }
  #endif
}
