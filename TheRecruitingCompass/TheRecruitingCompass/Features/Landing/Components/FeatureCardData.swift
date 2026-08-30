import Foundation

struct FeatureCardData: Identifiable {
  let id = UUID()
  let icon: String
  let title: String
  let description: String
}

extension FeatureCardData {
  static let landingFeatures: [FeatureCardData] = [
    FeatureCardData(
      icon: "building.columns.fill",
      title: String(localized: "Track Schools & Coaches"),
      description: String(localized: """
        A 5-stage pipeline for your college list and a full coach CRM \
        with response tracking and follow-up reminders.
        """)
    ),
    FeatureCardData(
      icon: "envelope.badge.fill",
      title: String(localized: "Smart Outreach"),
      description: String(localized: """
        33+ templates with NCAA contact-window compliance. \
        Your stats auto-fill into every message.
        """)
    ),
    FeatureCardData(
      icon: "calendar.badge.clock",
      title: String(localized: "Calendars & Timeline"),
      description: String(localized: """
        22 NCAA recruiting calendars and a 4-year roadmap with \
        milestones so you always know what to do next.
        """)
    )
  ]
}
