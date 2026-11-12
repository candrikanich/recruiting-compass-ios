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

  static func onboardingStarted(role: UserRole = .player) {
    logger.info("onboarding_v2_started role=\(role.rawValue)")
    Analytics.capture("onboarding_v2_started", properties: ["role": role.rawValue])
  }

  static func step1Complete(sport: String, gradYear: Int) {
    logger.info("onboarding_v2_step1_complete sport=\(sport) gradYear=\(gradYear)")
    Analytics.capture("onboarding_v2_step1_complete", properties: [
      "sport": sport,
      "gradYear": gradYear
    ])
  }

  /// School names are not sent: a custom school is free text.
  static func schoolAdded() {
    logger.info("onboarding_v2_school_added")
    Analytics.capture("onboarding_v2_school_added")
  }

  static func onboardingComplete(completedItems: Int = 0, role: UserRole = .player) {
    logger.info("onboarding_v2_complete role=\(role.rawValue) items=\(completedItems)")
    Analytics.capture("onboarding_v2_complete", properties: [
      "completedItems": completedItems,
      "role": role.rawValue
    ])
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
