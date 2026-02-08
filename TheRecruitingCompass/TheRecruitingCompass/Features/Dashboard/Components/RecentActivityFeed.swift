import SwiftUI

struct RecentActivityFeed: View {
  let activities: [Activity]

  private var sortedActivities: [Activity] {
    activities.sorted { $0.timestamp > $1.timestamp }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Recent Activity")
        .font(.headline)

      Divider()

      if sortedActivities.isEmpty {
        Text("No recent activity")
          .font(.caption)
          .foregroundColor(Color.secondaryText)
          .padding(.vertical)
      } else {
        VStack(spacing: 12) {
          ForEach(sortedActivities.prefix(5)) { activity in
            ActivityRow(activity: activity)
          }
        }

        if sortedActivities.count > 5 {
          Button("Show \(sortedActivities.count - 5) more activities") {
          }
          .font(.caption)
          .foregroundColor(Color.accentBlue)
        }
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
  }
}

struct ActivityRow: View {
  let activity: Activity

  private var timestampFormatted: String {
    guard let date = ISO8601DateFormatter().date(from: activity.timestamp) else {
      return activity.timestamp
    }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
  }

  private var activityIcon: String {
    switch activity.activityType {
    case "interaction_logged": return "bubble.left.and.bubble.right"
    case "offer_received": return "gift"
    case "school_added": return "building.2"
    case "event_scheduled": return "calendar"
    case "metric_updated": return "chart.line.uptrend.xyaxis"
    default: return "bell"
    }
  }

  private var activityColor: Color {
    switch activity.activityType {
    case "offer_received": return Color.successGreen
    case "interaction_logged": return Color.accentBlue
    case "school_added": return Color.primaryGreen
    default: return Color.iconGray
    }
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: activityIcon)
        .font(.body)
        .foregroundColor(activityColor)
        .frame(width: 24)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text(activity.description)
          .font(.subheadline)

        Text(timestampFormatted)
          .font(.caption)
          .foregroundColor(Color.secondaryText)
      }

      Spacer()
    }
    .padding(.vertical, 8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(activity.description)
    .accessibilityValue(timestampFormatted)
  }
}

#Preview {
  RecentActivityFeed(
    activities: [
      Activity(
        id: "1",
        activityType: "offer_received",
        description: "Received scholarship offer from State University",
        timestamp: "2026-02-07T10:00:00Z",
        userId: "user-1",
        relatedEntityId: "offer-1"
      ),
      Activity(
        id: "2",
        activityType: "interaction_logged",
        description: "Email sent to Coach Johnson",
        timestamp: "2026-02-06T15:30:00Z",
        userId: "user-1",
        relatedEntityId: "interaction-1"
      ),
      Activity(
        id: "3",
        activityType: "school_added",
        description: "Added Tech College to your list",
        timestamp: "2026-02-05T09:15:00Z",
        userId: "user-1",
        relatedEntityId: "school-1"
      )
    ]
  )
  .padding()
}
