import Foundation
import XCTest

/// Resolves the Supabase credentials E2E tests inject into the app under test.
///
/// E2E ALWAYS targets the local Supabase stack (`supabase start` in
/// recruiting-compass-web) by default. The local values are the standard
/// Supabase DEMO keys — public, identical on every local install, never
/// secrets — so they are safe to hard-code.
///
/// To point E2E at a different stack (e.g. an ephemeral CI database) set the
/// DEDICATED `E2E_SUPABASE_URL` / `E2E_SUPABASE_ANON_KEY` vars. We deliberately
/// IGNORE the ambient `SUPABASE_URL` / `SUPABASE_ANON_KEY`, because a developer's
/// local run scheme sets those to PRODUCTION for normal app runs — honoring them
/// here would silently run E2E (and the destructive seed) against prod.
enum E2ETestEnvironment {
  static let supabaseURL: String = {
    let fromEnv = ProcessInfo.processInfo.environment["E2E_SUPABASE_URL"] ?? ""
    return fromEnv.isEmpty ? "http://127.0.0.1:54321" : fromEnv
  }()

  static let supabaseAnonKey: String = {
    let fromEnv = ProcessInfo.processInfo.environment["E2E_SUPABASE_ANON_KEY"] ?? ""
    guard fromEnv.isEmpty else { return fromEnv }
    return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
  }()

  /// Launch arguments + environment every E2E test should apply to its XCUIApplication.
  /// Animations are off by default (faster, less simulator CPU, fewer mid-transition taps);
  /// recordings and timing baselines pass `animated: true` to see what users see.
  static func configure(_ app: XCUIApplication, animated: Bool = false) {
    app.launchArguments = animated ? ["--uitesting"] : ["--uitesting", "--disable-animations"]
    // A remote E2E project means a CI runner, which never completes the Cloudflare
    // challenge; that project has captcha disabled, so the app may skip it. Local runs
    // keep exercising the real widget.
    if !(ProcessInfo.processInfo.environment["E2E_SUPABASE_URL"] ?? "").isEmpty {
      app.launchArguments.append("--e2e-captcha-bypass")
    }
    app.launchEnvironment = [
      "SUPABASE_URL": supabaseURL,
      "SUPABASE_ANON_KEY": supabaseAnonKey
    ]
    // Family join/leave and labels go through the web API; pointing at the local web dev server keeps them off prod.
    if let apiBaseURL = ProcessInfo.processInfo.environment["E2E_API_BASE_URL"], !apiBaseURL.isEmpty {
      app.launchEnvironment["API_BASE_URL"] = apiBaseURL
    }
  }

  /// Tests that call the family API must run against the local web server: without `E2E_API_BASE_URL` the app
  /// would use the embedded (production) API base URL, which a seeded local database cannot satisfy.
  static func requireAPIBaseURL() throws {
    let value = ProcessInfo.processInfo.environment["E2E_API_BASE_URL"] ?? ""
    guard !value.isEmpty else {
      throw E2ESetupError.missingAPIBaseURL
    }
  }
}

enum E2ESetupError: Error, CustomStringConvertible {
  case missingAPIBaseURL

  var description: String {
    "E2E_API_BASE_URL is not set: run with TEST_RUNNER_E2E_API_BASE_URL=<local web dev server> so family calls " +
      "never reach the production API"
  }
}
