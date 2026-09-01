import os

/// Analytics for onboarding events. Dual: os.Logger for debug + PostHog for product analytics.
enum OnboardingAnalytics {
  private static let logger = Logger(
    subsystem: "com.chrisandrikanich.TheRecruitingCompass",
    category: "OnboardingAnalytics"
  )

  static func onboardingStarted() {
    logger.info("onboarding_v2_started")
    Analytics.capture("onboarding_v2_started")
  }

  static func step1Complete(sport: String, gradYear: Int) {
    logger.info("onboarding_v2_step1_complete sport=\(sport) gradYear=\(gradYear)")
    Analytics.capture("onboarding_v2_step1_complete", properties: [
      "sport": sport,
      "gradYear": gradYear,
    ])
  }

  static func schoolAdded(schoolName: String) {
    logger.info("onboarding_v2_school_added school=\(schoolName)")
    Analytics.capture("onboarding_v2_school_added", properties: [
      "schoolName": schoolName,
    ])
  }

  static func onboardingComplete(completedItems: Int) {
    logger.info("onboarding_v2_complete items=\(completedItems)")
    Analytics.capture("onboarding_v2_complete", properties: [
      "completedItems": completedItems,
    ])
  }

  static func checklistItemCompleted(item: String) {
    logger.info("checklist_item_completed item=\(item)")
    Analytics.capture("checklist_item_completed", properties: [
      "item": item,
    ])
  }

  static func checklistDismissed() {
    logger.info("checklist_dismissed")
    Analytics.capture("checklist_dismissed")
  }
}
