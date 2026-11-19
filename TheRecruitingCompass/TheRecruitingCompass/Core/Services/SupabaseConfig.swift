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

/// Reads Supabase URL from (1) env under `--uitesting` (required: missing is fatal, embedded is never used),
/// otherwise (2) embedded Swift, (3) env, (4) Info.plist, (5) plist, (6) production fallback.
private func supabaseURLString() -> String {
  let environment = ProcessInfo.processInfo.environment
  switch UITestBackendOverride.requiredSetting(
    "SUPABASE_URL", isUITesting: isUITesting, environment: environment, otherwise: normalSupabaseURLString
  ) {
  case .success(let url): return url
  case .failure(let missing): fatalError(missing.description)
  }
}

private func normalSupabaseURLString() -> String {
  let fromEnv = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? ""
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

/// Reads Supabase anon key like `supabaseURLString`: env-only and required under `--uitesting`.
private func supabaseAnonKey() -> String {
  let environment = ProcessInfo.processInfo.environment
  switch UITestBackendOverride.requiredSetting(
    "SUPABASE_ANON_KEY", isUITesting: isUITesting, environment: environment, otherwise: normalSupabaseAnonKey
  ) {
  case .success(let key): return key
  case .failure(let missing): fatalError(missing.description)
  }
}

private func normalSupabaseAnonKey() -> String {
  let fromEnv = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
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
  /// True when the UI-test launch environment supplied the backend, i.e. `url` is a test
  /// stack rather than the embedded project. Always false in Release.
  static var isUITestBackendOverride: Bool {
    let resolved = UITestBackendOverride.resolve(
      "SUPABASE_URL", isUITesting: isUITesting, environment: ProcessInfo.processInfo.environment
    )
    if case .value = resolved { return true }
    return false
  }

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
  /// Normal launches: (1) scheme env var API_BASE_URL (debug), (2) Release.xcconfig API_BASE_URL via embedded config,
  /// (3) production fallback (Release only). Under `--uitesting`: the env var or `nil`, never (2) or (3).
  nonisolated static let apiBaseURL: URL? = {
    #if DEBUG
    let releaseFallback = ""
    #else
    let releaseFallback = "https://myrecruitingcompass.com"
    #endif
    return UITestBackendOverride.apiBaseURL(
      isUITesting: isUITesting,
      environment: ProcessInfo.processInfo.environment,
      embedded: SupabaseConfigEmbedded.apiBaseURL,
      releaseFallback: releaseFallback
    )
  }()
}
