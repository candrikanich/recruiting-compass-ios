import SwiftUI

/// Header section for coach detail view with initials, name, role, and school.
struct CoachDetailHeader: View {
  let coach: Coach
  let school: School?

  @Environment(\.sizeCategory) private var sizeCategory

  private enum Layout {
    static let initialsCircleSize: CGFloat = 100
    static let initialsCircleAccessibilitySize: CGFloat = 120
  }

  var body: some View {
    VStack(spacing: 16) {
      // Large initials circle
      Text(coach.initials)
        .font(.largeTitle.bold())
        .foregroundStyle(.white)
        .frame(
          width: sizeCategory.isAccessibilityCategory ? Layout.initialsCircleAccessibilitySize : Layout.initialsCircleSize,
          height: sizeCategory.isAccessibilityCategory ? Layout.initialsCircleAccessibilitySize : Layout.initialsCircleSize
        )
        .background(
          LinearGradient(
            colors: [.blueGradientStart, Color(hex: "7C3AED")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .clipShape(Circle())
        .accessibilityHidden(true)

      Text(coach.fullName)
        .font(.title2.bold())
        .accessibilityAddTraits(.isHeader)

      HStack(spacing: 8) {
        Text(coach.role.displayName)
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundStyle(.white)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(coach.role.badgeColor)
          .clipShape(Capsule())
          .accessibilityLabel("Role: \(coach.role.displayName)")

        if let school = school {
          Text(school.name)
            .font(.subheadline)
            .foregroundStyle(Color.accentBlue)
        }
      }
    }
    .frame(maxWidth: .infinity)
  }
}

#Preview {
  VStack(spacing: 40) {
    CoachDetailHeader(
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
        responsivenessScore: 85,
        lastContactDate: "2026-01-15T10:00:00Z",
        createdAt: "2025-01-01T00:00:00Z",
        updatedAt: "2026-01-15T10:00:00Z"
      ),
      school: School(
        id: "school-1",
        userId: "user-1",
        name: "State University",
        location: "State College, PA",
        city: "State College",
        state: "PA",
        division: "D1",
        conference: "Big Ten",
        ranking: 25,
        isFavorite: false,
        website: nil,
        faviconUrl: nil,
        twitterHandle: nil,
        instagramHandle: nil,
        ncaaId: nil,
        status: "interested",
        statusChangedAt: nil,
        notes: nil,
        privateNotes: nil,
        pros: [],
        cons: [],
        offerDetails: nil,
        academicInfo: nil,
        amenities: nil,
        coachingPhilosophy: nil,
        coachingStyle: nil,
        recruitingApproach: nil,
        communicationStyle: nil,
        successMetrics: nil,
        fitScore: nil,
        fitTier: nil,
        familyUnitId: "family-1",
        createdBy: nil,
        updatedBy: nil,
        createdAt: "2025-01-01T00:00:00Z",
        updatedAt: "2025-01-01T00:00:00Z"
      )
    )

    CoachDetailHeader(
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
        responsivenessScore: 60,
        lastContactDate: nil,
        createdAt: "2025-01-01T00:00:00Z",
        updatedAt: "2025-01-01T00:00:00Z"
      ),
      school: nil
    )
  }
  .padding()
}
