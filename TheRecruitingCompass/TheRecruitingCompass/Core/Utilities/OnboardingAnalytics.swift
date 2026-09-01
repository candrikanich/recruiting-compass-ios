import os

/// Analytics stubs for onboarding events. Logs to os.Logger until PostHog is integrated.
// TODO: Replace with PostHog capture() calls when SDK is integrated
enum OnboardingAnalytics {
  private static let logger = Logger(
    subsystem: "com.chrisandrikanich.TheRecruitingCompass",
    category: "OnboardingAnalytics"
  )

  static func onboardingStarted() {
    logger.info("onboarding_v2_started")
  }

  static func step1Complete(sport: String, gradYear: Int) {
    logger.info("onboarding_v2_step1_complete sport=\(sport) gradYear=\(gradYear)")
  }

  static func schoolAdded(schoolName: String) {
    logger.info("onboarding_v2_school_added school=\(schoolName)")
  }

  static func onboardingComplete(completedItems: Int) {
    logger.info("onboarding_v2_complete items=\(completedItems)")
  }

  static func checklistItemCompleted(item: String) {
    logger.info("checklist_item_completed item=\(item)")
  }

  static func checklistDismissed() {
    logger.info("checklist_dismissed")
  }
}
