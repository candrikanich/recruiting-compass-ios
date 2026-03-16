import SwiftUI

/// Statistics section for coach detail view showing last contact date.
struct CoachStatisticsSection: View {
  let coach: Coach

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
