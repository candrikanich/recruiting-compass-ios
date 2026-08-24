import SwiftUI

/// Timeline Guidance widget showing the athlete's next NCAA recruiting-calendar
/// milestones (tests, deadlines, applications, signing dates, NCAA periods).
/// Standalone extraction of `RecruitingCalendarWidget`'s milestone list — this
/// view owns only presentation; all milestone selection stays in
/// `RecruitingCalendar.upcomingMilestones`. Ported for parity with the web
/// `components/Timeline/UpcomingMilestones.vue` widget (icon set, row layout,
/// external-link affordance, empty copy).
struct UpcomingMilestonesWidget: View {
  let milestones: [CalendarMilestone]

  private static let displayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy"
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()

  private static let isoFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone.current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if milestones.isEmpty {
        Text(String(localized: "No upcoming milestones in the next 6 months."))
          .font(.subheadline)
          .foregroundStyle(Color.secondaryText)
      } else {
        ForEach(Array(milestones.enumerated()), id: \.offset) { _, milestone in
          milestoneRow(for: milestone)
        }
      }
    }
  }

  @ViewBuilder
  private func milestoneRow(for milestone: CalendarMilestone) -> some View {
    if let urlString = milestone.url, let url = URL(string: urlString) {
      Link(destination: url) {
        milestoneRowContent(for: milestone, showsExternalLinkAffordance: true)
      }
    } else {
      milestoneRowContent(for: milestone, showsExternalLinkAffordance: false)
    }
  }

  private func milestoneRowContent(
    for milestone: CalendarMilestone,
    showsExternalLinkAffordance: Bool
  ) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Text(icon(for: milestone.type))
        .font(.title2)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text(milestone.title)
          .font(.subheadline.weight(.medium))
        Text(formattedDate(milestone.date))
          .font(.caption)
          .foregroundStyle(Color.secondaryText)
        if let description = milestone.description {
          Text(description)
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
        }
      }

      if showsExternalLinkAffordance {
        Spacer()
        Image(systemName: "arrow.up.right")
          .font(.caption)
          .foregroundStyle(Color.secondaryText)
          .accessibilityHidden(true)
      }
    }
    .padding(12)
    .background(Color.Surface.muted)
    .clipShape(.rect(cornerRadius: 8))
  }

  private func formattedDate(_ dateISO: String) -> String {
    guard let date = Self.isoFormatter.date(from: dateISO) else { return dateISO }
    return Self.displayFormatter.string(from: date)
  }

  private func icon(for type: MilestoneType) -> String {
    switch type {
    case .test: return "📝"
    case .deadline: return "⏰"
    case .ncaaPeriod: return "📋"
    case .application: return "📧"
    case .signing: return "✍️"
    }
  }
}

#Preview {
  UpcomingMilestonesWidget(milestones: RecruitingCalendar.upcomingMilestones(
    "2026-08-24", sport: "Baseball", division: "D1", gender: "male", graduationYear: nil
  ))
  .padding()
}
