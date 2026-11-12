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

  /// Where events go. Tests swap in a recording double so nothing reaches PostHog.
  nonisolated(unsafe) static var transport: any AnalyticsTransport = PostHogTransport()

  /// Identify the authenticated user by opaque ID only (Chris, 2026-10-30): no email or other direct
  /// identifier is ever sent, so this takes none.
  static func identify(userId: String, role: String? = nil) {
    var properties: [String: Any] = ["platform": "ios"]
    if let role { properties["role"] = role }
    transport.identify(userId: userId, properties: properties)
  }

  /// Reset identity on sign-out so the next user gets a clean anonymous ID.
  static func reset() {
    transport.reset()
  }

  /// Capture a named event with optional properties (platform always included).
  static func capture(_ event: String, properties: [String: Any] = [:]) {
    var props = properties
    props["platform"] = "ios"
    transport.capture(event, properties: props)
  }
}

protocol AnalyticsTransport: Sendable {
  func identify(userId: String, properties: [String: Any])
  func reset()
  func capture(_ event: String, properties: [String: Any])
}

/// No-ops when the PostHog key is missing (debug without PostHog).
struct PostHogTransport: AnalyticsTransport {
  func identify(userId: String, properties: [String: Any]) {
    guard !Analytics.apiKey.isEmpty else { return }
    PostHogSDK.shared.identify(userId, userProperties: properties)
  }

  func reset() {
    guard !Analytics.apiKey.isEmpty else { return }
    PostHogSDK.shared.reset()
  }

  func capture(_ event: String, properties: [String: Any]) {
    guard !Analytics.apiKey.isEmpty else { return }
    PostHogSDK.shared.capture(event, properties: properties)
  }
}
