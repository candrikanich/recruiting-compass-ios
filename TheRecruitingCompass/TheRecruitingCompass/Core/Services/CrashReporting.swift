import Foundation
import OSLog
import Sentry

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "CrashReporting")

/// Sentry crash + app-hang reporting. Deliberately anonymous: no user id, no PII, no performance tracing,
/// which keeps the App Privacy label at "Crash Data / Other Diagnostic Data — not linked to you".
enum CrashReporting {
  /// `SentryDSN` exists only in the Release Info.plist, populated from the `SENTRY_DSN` build setting.
  static func dsn(from infoDictionary: [String: Any]?) -> String? {
    guard let value = infoDictionary?["SentryDSN"] as? String else { return nil }
    let dsn = value.trimmingCharacters(in: .whitespaces)
    // An unset build setting can survive as the literal "$(SENTRY_DSN)".
    guard !dsn.isEmpty, !dsn.hasPrefix("$(") else { return nil }
    return dsn
  }

  /// Call once at launch, before anything else can crash. No-ops without a DSN (Debug, local builds).
  static func start(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) {
    guard let dsn = dsn(from: infoDictionary) else {
      logger.info("SENTRY_DSN not configured — crash reporting disabled")
      return
    }
    SentrySDK.start { options in
      options.dsn = dsn
      options.sendDefaultPii = false
      options.enableAppHangTracking = true
      options.attachScreenshot = false
      options.attachViewHierarchy = false
    }
  }
}
