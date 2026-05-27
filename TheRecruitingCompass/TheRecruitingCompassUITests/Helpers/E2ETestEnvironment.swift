import Foundation
import XCTest

/// Resolves the Supabase credentials E2E tests inject into the app under test.
///
/// Priority: the test runner's own environment (`SUPABASE_URL` / `SUPABASE_ANON_KEY`,
/// set by CI or a scheme) wins; otherwise we fall back to the local Supabase stack
/// started via `supabase start` in recruiting-compass-web. The local values are the
/// standard Supabase DEMO keys — public, identical on every local install, never
/// secrets — so it is safe to hard-code them as the default. This guarantees E2E
/// runs hit a local DB, never production.
enum E2ETestEnvironment {
  static let supabaseURL: String = {
    let fromEnv = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? ""
    return fromEnv.isEmpty ? "http://127.0.0.1:54321" : fromEnv
  }()

  static let supabaseAnonKey: String = {
    let fromEnv = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    guard fromEnv.isEmpty else { return fromEnv }
    return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
  }()

  /// Launch arguments + environment every E2E test should apply to its XCUIApplication.
  static func configure(_ app: XCUIApplication) {
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": supabaseURL,
      "SUPABASE_ANON_KEY": supabaseAnonKey,
    ]
  }
}
