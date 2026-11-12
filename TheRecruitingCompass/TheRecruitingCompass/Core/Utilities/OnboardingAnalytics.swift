import Foundation
import os

/// Analytics for onboarding events. Dual: os.Logger for debug + PostHog for product analytics.
enum OnboardingAnalytics {
  private static let logger = Logger(
    subsystem: "com.chrisandrikanich.TheRecruitingCompass",
    category: "OnboardingAnalytics"
  )

  /// Fires once per new account. Role only: never name, email or date of birth.
  static func signupCompleted(role: UserRole) {
    logger.info("signup_completed role=\(role.rawValue)")
    Analytics.capture("signup_completed", properties: ["role": role.rawValue])
  }

  /// Where the once-per-user "started sent" flag lives. Tests swap in an isolated suite.
  nonisolated(unsafe) static var defaults: UserDefaults = .standard

  /// Fires once per user, however often the onboarding screen appears. The flag is only set when the
  /// event is actually sent, so a call with no known role/user (see `startedIfKnown`) can retry later.
  static func onboardingStarted(role: UserRole, userId: String) {
    let key = "analytics.onboardingStartedSent.\(userId)"
    guard !defaults.bool(forKey: key) else { return }
    defaults.set(true, forKey: key)
    logger.info("onboarding_v2_started role=\(role.rawValue)")
    Analytics.capture("onboarding_v2_started", properties: ["role": role.rawValue])
  }

  /// Onboarding can appear before the user's role is loaded. Sending a guessed role would corrupt the
  /// player/parent split, so with no user or role nothing is sent and the next appearance tries again.
  static func onboardingStarted(user: User?) {
    guard let user, let role = user.role else { return }
    onboardingStarted(role: role, userId: user.id)
  }

  static func step1Complete(sport: String, gradYear: Int) {
    logger.info("onboarding_v2_step1_complete sport=\(sport) gradYear=\(gradYear)")
    Analytics.capture("onboarding_v2_step1_complete", properties: [
      "sport": sport,
      "gradYear": gradYear
    ])
  }

  /// School names are not sent: product analytics don't need which school a user picked.
  static func schoolAdded() {
    logger.info("onboarding_v2_school_added")
    Analytics.capture("onboarding_v2_school_added")
  }

  /// `completedItems` only applies to the player flow (schools added); parents have no such count.
  static func onboardingComplete(role: UserRole, completedItems: Int? = nil) {
    logger.info("onboarding_v2_complete role=\(role.rawValue) items=\(completedItems ?? -1)")
    var properties: [String: Any] = ["role": role.rawValue]
    if let completedItems { properties["completedItems"] = completedItems }
    Analytics.capture("onboarding_v2_complete", properties: properties)
  }

  static func checklistItemCompleted(item: String, role: UserRole) {
    logger.info("checklist_item_completed item=\(item) role=\(role.rawValue)")
    Analytics.capture("checklist_item_completed", properties: [
      "item": item,
      "role": role.rawValue
    ])
  }

  static func checklistDismissed() {
    logger.info("checklist_dismissed")
    Analytics.capture("checklist_dismissed")
  }
}
