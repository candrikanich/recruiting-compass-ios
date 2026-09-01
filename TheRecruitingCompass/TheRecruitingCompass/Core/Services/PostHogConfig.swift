import Foundation
import OSLog
import PostHog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "Analytics")

/// PostHog API key cascade: (1) Release.xcconfig embedded, (2) env var, (3) empty (disabled).
/// Same pattern as SupabaseConfig — never hardcode the key.
private func posthogAPIKey() -> String {
  let embedded = PostHogConfigEmbedded.apiKey
  if !embedded.isEmpty, !embedded.contains("placeholder") { return embedded }
  let fromEnv = ProcessInfo.processInfo.environment["POSTHOG_API_KEY"] ?? ""
  if !fromEnv.isEmpty { return fromEnv }
  return ""
}

/// Thin wrapper around PostHogSDK for app-wide analytics.
/// Named `Analytics` to avoid colliding with the SDK's own `PostHogConfig` class.
enum Analytics {
  static let apiKey = posthogAPIKey()
  private static let host = "https://us.i.posthog.com"

  /// Call once at app launch. Silently no-ops when the key is missing (debug without PostHog).
  static func setup() {
    let key = apiKey
    guard !key.isEmpty else {
      logger.warning("POSTHOG_API_KEY not configured — analytics disabled")
      return
    }
    let config = PostHogConfig(projectToken: key, host: host)
    PostHogSDK.shared.setup(config)
    logger.info("PostHog initialized")
  }

  /// Identify the authenticated user. Call after successful login or session restore.
  static func identify(userId: String, email: String? = nil, role: String? = nil) {
    guard !apiKey.isEmpty else { return }
    var properties: [String: Any] = ["platform": "ios"]
    if let email { properties["email"] = email }
    if let role { properties["role"] = role }
    PostHogSDK.shared.identify(userId, userProperties: properties)
  }

  /// Reset identity on sign-out so the next user gets a clean anonymous ID.
  static func reset() {
    guard !apiKey.isEmpty else { return }
    PostHogSDK.shared.reset()
  }

  /// Capture a named event with optional properties (platform always included).
  static func capture(_ event: String, properties: [String: Any] = [:]) {
    guard !apiKey.isEmpty else { return }
    var props = properties
    props["platform"] = "ios"
    PostHogSDK.shared.capture(event, properties: props)
  }
}
