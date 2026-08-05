import SwiftUI

/// Statistics section for coach detail view showing last contact date and next contact date.
struct CoachStatisticsSection: View {
  let coach: Coach

  private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f
  }()

  private static let isoDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
  }()

  private var nextContactDateParsed: Date? {
    guard let dateString = coach.nextContactDate else { return nil }
    return CoachStatisticsSection.isoDateFormatter.date(from: dateString)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Statistics")

      if let lastContact = coach.lastContactDateParsed {
        HStack(spacing: 8) {
          Image(systemName: "clock")
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
          Text("Last contacted \(lastContact, style: .relative) ago")
            .font(.subheadline)
        }
      } else {
        HStack(spacing: 8) {
          Image(systemName: "clock")
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
          Text("Never contacted")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .italic()
        }
      }

      if let nextContact = nextContactDateParsed {
        HStack(spacing: 8) {
          Image(systemName: "calendar.badge.clock")
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
          Text("Next contact: \(CoachStatisticsSection.dateFormatter.string(from: nextContact))")
            .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Next contact date: \(CoachStatisticsSection.dateFormatter.string(from: nextContact))"))
      }

      HStack(spacing: 8) {
        Image(systemName: "bell")
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
        Text("Follow-up threshold: \(coach.followUpThresholdDays ?? 21) days")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .accessibilityLabel(String(localized: "Follow-up threshold: \(coach.followUpThresholdDays ?? 21) days"))
    }
  }
}

#Preview {
  VStack(spacing: 40) {
    CoachStatisticsSection(
      coach: Coach(
        id: "1",
        firstName: "John",
        lastName: "Smith",
        email: "john@university.edu",
        phone: "555-0123",
        position: "head",
        schoolId: "school-1",
        twitterHandle: "@coachsmith",
        instagramHandle: "@coachsmith",
        notes: "Great recruiter",
        lastContactDate: "2026-01-15T10:00:00Z",
        createdAt: "2025-01-01T00:00:00Z",
        updatedAt: "2026-01-15T10:00:00Z"
      )
    )

    CoachStatisticsSection(
      coach: Coach(
        id: "2",
        firstName: "Jane",
        lastName: "Doe",
        email: nil,
        phone: nil,
        position: "assistant",
        schoolId: "school-2",
        twitterHandle: nil,
        instagramHandle: nil,
        notes: nil,
        lastContactDate: nil,
        createdAt: "2025-01-01T00:00:00Z",
        updatedAt: "2025-01-01T00:00:00Z"
      )
    )
  }
  .padding()
}
