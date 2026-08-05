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
  static func configure(_ app: XCUIApplication) {
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": supabaseURL,
      "SUPABASE_ANON_KEY": supabaseAnonKey
    ]
  }
}
