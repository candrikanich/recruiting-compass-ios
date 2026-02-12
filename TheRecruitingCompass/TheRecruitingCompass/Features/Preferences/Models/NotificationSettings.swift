import Foundation

struct NotificationSettings: Codable, Equatable {
  var followUpReminderDays: Int
  var enableFollowUpReminders: Bool
  var enableDeadlineAlerts: Bool
  var enableDailyDigest: Bool
  var enableInboundInteractionAlerts: Bool
  var enableEmailNotifications: Bool
  var emailOnlyHighPriority: Bool
  var quietHoursStart: String?
  var quietHoursEnd: String?

  static var `default`: NotificationSettings {
    NotificationSettings(
      followUpReminderDays: 7,
      enableFollowUpReminders: true,
      enableDeadlineAlerts: true,
      enableDailyDigest: true,
      enableInboundInteractionAlerts: true,
      enableEmailNotifications: true,
      emailOnlyHighPriority: false,
      quietHoursStart: nil,
      quietHoursEnd: nil
    )
  }

  enum CodingKeys: String, CodingKey {
    case followUpReminderDays
    case enableFollowUpReminders
    case enableDeadlineAlerts
    case enableDailyDigest
    case enableInboundInteractionAlerts
    case enableEmailNotifications
    case emailOnlyHighPriority
    case quietHoursStart
    case quietHoursEnd
  }
}
