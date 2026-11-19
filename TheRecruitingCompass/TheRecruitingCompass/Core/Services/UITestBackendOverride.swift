import Foundation

/// How a backend setting behaves under the UI-test runner (`--uitesting`).
///
/// A UI test that forgets (or overwrites) its launch environment must not quietly inherit the embedded
/// config, which is production in any local build. Under `--uitesting` the launch environment value is used or
/// the setting is treated as absent; the embedded/plist/production sources are never consulted (ios #582).
enum UITestBackendOverride: Equatable {
  /// Not a UI-test launch: resolve the setting the normal way.
  case inactive
  /// UI-test launch with the setting supplied by the launch environment.
  case value(String)
  /// UI-test launch without the setting (absent, empty or whitespace): never fall back to embedded config.
  case missing

  static func resolve(_ key: String, isUITesting: Bool, environment: [String: String]) -> UITestBackendOverride {
    guard isUITesting else { return .inactive }
    let value = (environment[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? .missing : .value(value)
  }

  /// A setting the app cannot run without. The caller turns `.failure` into a fatal error.
  struct MissingSetting: Error, Equatable, CustomStringConvertible {
    let key: String
    var description: String {
      "--uitesting requires \(key) in the launch environment (use E2ETestEnvironment.configure); " +
        "refusing the embedded config, which is production."
    }
  }

  /// Under `--uitesting` returns the launch-environment value or `.failure`, and never evaluates `otherwise`.
  static func requiredSetting(
    _ key: String,
    isUITesting: Bool,
    environment: [String: String],
    otherwise: () -> String
  ) -> Result<String, MissingSetting> {
    switch resolve(key, isUITesting: isUITesting, environment: environment) {
    case .value(let value): return .success(value)
    case .missing: return .failure(MissingSetting(key: key))
    case .inactive: return .success(otherwise())
    }
  }

  /// Web API base URL. Under `--uitesting` it is the launch-environment value or `nil` ("no web API"); the
  /// embedded and release-fallback URLs are only consulted on a normal launch.
  static func apiBaseURL(
    isUITesting: Bool,
    environment: [String: String],
    embedded: String,
    releaseFallback: String
  ) -> URL? {
    switch resolve("API_BASE_URL", isUITesting: isUITesting, environment: environment) {
    case .missing: return nil
    case .value(let value): return url(from: value)
    case .inactive:
      let fromEnv = (environment["API_BASE_URL"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      let candidates = [fromEnv, embedded, releaseFallback]
      guard let usable = candidates.first(where: { !$0.isEmpty && !$0.contains("placeholder") }) else { return nil }
      return url(from: usable)
    }
  }

  private static func url(from string: String) -> URL? {
    URL(string: string.contains("://") ? string : "https://" + string)
  }
}
