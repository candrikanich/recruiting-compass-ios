import Foundation

/// How a backend setting behaves under the UI-test runner (`--uitesting`).
///
/// A UI test that forgets (or overwrites) its launch environment must not quietly inherit the embedded
/// config, which is production in any local build. `.missing` tells the caller to fail closed (ios #582).
enum UITestBackendOverride: Equatable {
  /// Not a UI-test launch: resolve the setting the normal way.
  case inactive
  /// UI-test launch with the setting supplied by the launch environment.
  case value(String)
  /// UI-test launch without the setting (absent, empty or whitespace): never fall back to embedded config.
  case missing

  static func resolve(_ key: String, isUITesting: Bool, environment: [String: String]) -> UITestBackendOverride {
    guard isUITesting else { return .inactive }
    let value = (environment[key] ?? "").trimmingCharacters(in: .whitespaces)
    return value.isEmpty ? .missing : .value(value)
  }
}
