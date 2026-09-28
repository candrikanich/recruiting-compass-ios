import Foundation

/// Identity of the running build, for display, the App Store link, and server-side version tracking.
enum AppInfo {
  static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
  static let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
  static var displayVersion: String { "\(version) (\(build))" }

  static let appStoreURL = URL(string: "https://apps.apple.com/app/id6758562332")!

  /// Sent on Supabase and web-API requests so the server can see (and eventually refuse) old clients.
  static let clientHeaders: [String: String] = [
    "X-Client-Platform": "ios",
    "X-Client-Version": version,
    "X-Client-Build": build
  ]
}

extension URLRequest {
  mutating func addClientHeaders() {
    for (field, value) in AppInfo.clientHeaders {
      setValue(value, forHTTPHeaderField: field)
    }
  }
}
