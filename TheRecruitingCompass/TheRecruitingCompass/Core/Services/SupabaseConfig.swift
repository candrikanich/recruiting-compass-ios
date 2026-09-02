import Foundation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "SupabaseConfig")

private let placeholderURLString = "https://placeholder.supabase.co"
private let placeholderKey = "placeholder-key"

/// Production fallback when embedded/plist/env fail (e.g. TestFlight). Set real values in Release.xcconfig (gitignored).
private let productionURLString = ""
private let productionAnonKey = ""

/// True when launched by the UI test runner. Lets E2E tests point the app at a
/// local Supabase stack via launchEnvironment instead of the embedded prod creds.
/// Debug-only: a Release binary must never honor a backend override.
private var isUITesting: Bool {
  #if DEBUG
  ProcessInfo.processInfo.arguments.contains("--uitesting")
  #else
  false
  #endif
}

/// Reads Supabase URL from (1) embedded Swift, (2) env, (3) Info.plist, (4) plist, (5) production fallback.
/// Under UI testing, env vars take priority so E2E runs against a local stack, never prod.
private func supabaseURLString() -> String {
  let fromEnv = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? ""
  if isUITesting, !fromEnv.isEmpty { return fromEnv }
  // Embedded values from SupabaseConfig.generated.swift — always available in built app
  let embedded = SupabaseConfigEmbedded.urlString
  if !embedded.isEmpty, !embedded.contains("placeholder") { return embedded }
  if !fromEnv.isEmpty { return fromEnv }
  if let fromInfo = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String, !fromInfo.isEmpty { return fromInfo }
  if let plistURL = Bundle.main.url(forResource: "SupabaseConfig", withExtension: "plist"),
     let dict = NSDictionary(contentsOf: plistURL) as? [String: Any],
     let s = dict["SUPABASE_URL"] as? String, !s.isEmpty { return s }
  #if !DEBUG
  return productionURLString
  #else
  return ""
  #endif
}

/// Reads Supabase anon key from (1) embedded Swift, (2) env, (3) Info.plist, (4) plist, (5) production fallback.
private func supabaseAnonKey() -> String {
  let fromEnv = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
  if isUITesting, !fromEnv.isEmpty { return fromEnv }
  let embedded = SupabaseConfigEmbedded.anonKey
  if !embedded.isEmpty, embedded != placeholderKey { return embedded }
  if !fromEnv.isEmpty { return fromEnv }
  if let fromInfo = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String, !fromInfo.isEmpty { return fromInfo }
  if let plistURL = Bundle.main.url(forResource: "SupabaseConfig", withExtension: "plist"),
     let dict = NSDictionary(contentsOf: plistURL) as? [String: Any],
     let s = dict["SUPABASE_ANON_KEY"] as? String, !s.isEmpty { return s }
  #if !DEBUG
  return productionAnonKey
  #else
  return ""
  #endif
}

struct SupabaseConfig {
  static let url: URL = {
    let urlString = supabaseURLString()
    if let url = URL(string: urlString), !urlString.isEmpty, !urlString.contains("placeholder") {
      return url
    }
    #if DEBUG
    logger.warning("SUPABASE_URL not configured - using placeholder (DEBUG only)")
    guard let placeholderURL = URL(string: placeholderURLString) else {
      fatalError("Invalid placeholder URL in SupabaseConfig")
    }
    return placeholderURL
    #else
    fatalError(
      "SUPABASE_URL must be set for Release builds. " +
      "Configure in Release.xcconfig. Archive/TestFlight builds do not inherit scheme env vars."
    )
    #endif
  }()

  static let anonKey: String = {
    let key = supabaseAnonKey()
    if !key.isEmpty, key != placeholderKey {
      return key
    }
    #if DEBUG
    logger.warning("SUPABASE_ANON_KEY not configured - using placeholder (DEBUG only)")
    return placeholderKey
    #else
    fatalError("SUPABASE_ANON_KEY must be set for Release builds. Configure in Release.xcconfig. Archive/TestFlight builds do not inherit scheme env vars.")
    #endif
  }()

  /// Base URL for Recruiting Compass API (e.g. https://myrecruitingcompass.com). Used for invite join, suggestions, and family API calls.
  /// Reads from: (1) scheme env var API_BASE_URL (debug), (2) Release.xcconfig API_BASE_URL via embedded config, (3) production fallback.
  nonisolated static let apiBaseURL: URL? = {
    // (1) Scheme env var — works in debug/device runs from Xcode
    var urlString = (ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "").trimmingCharacters(in: .whitespaces)
    // (2) Embedded from Release.xcconfig at build time (same mechanism as Supabase credentials)
    if urlString.isEmpty || urlString.contains("placeholder") {
      let embedded = SupabaseConfigEmbedded.apiBaseURL
      if !embedded.isEmpty, !embedded.contains("placeholder") {
        urlString = embedded
      }
    }
    // (3) Production fallback for TestFlight/App Store
    if urlString.isEmpty || urlString.contains("placeholder") {
      #if !DEBUG
      urlString = "https://myrecruitingcompass.com"
      #endif
    }
    guard !urlString.isEmpty, !urlString.contains("placeholder") else { return nil }
    if !urlString.contains("://") { urlString = "https://" + urlString }
    return URL(string: urlString)
  }()
}
