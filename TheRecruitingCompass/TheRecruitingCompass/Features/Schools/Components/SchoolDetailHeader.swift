import SwiftUI

struct SchoolDetailHeader: View {
  let school: School
  let onToggleFavorite: () -> Void

  @Environment(\.sizeCategory) private var sizeCategory

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 16) {
        // School logo or initials
        ZStack {
          RoundedRectangle(cornerRadius: 12)
            .fill(Color.blue.opacity(0.2))
            .frame(width: 56, height: 56)

          if let faviconUrl = school.faviconUrl, let url = URL(string: faviconUrl) {
            AsyncImage(url: url) { image in
              image
                .resizable()
                .scaledToFit()
            } placeholder: {
              Text(school.initials)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.blue)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12))
          } else {
            Text(school.initials)
              .font(.title2)
              .fontWeight(.bold)
              .foregroundStyle(.blue)
          }
        }
        .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          Text(school.name)
            .font(.title2)
            .fontWeight(.bold)
            .lineLimit(2)
            .minimumScaleFactor(0.9)

          if let location = school.location {
            Label {
              Text(location)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } icon: {
              Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            }
          }
        }

        Spacer()

        Button(action: onToggleFavorite) {
          Image(systemName: school.isFavorite ? "star.fill" : "star")
            .foregroundStyle(school.isFavorite ? .yellow : .gray)
            .font(.title2)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("favorite-button")
        .accessibilityLabel(school.isFavorite ? "Unfavorite" : "Favorite")
        .accessibilityHint(school.isFavorite ? "Remove from favorites" : "Add to favorites")
      }

      // Badges row
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          if let division = school.division {
            DivisionBadge(division: division)
          }

          StatusBadge(status: SchoolStatus(rawValue: school.status) ?? .interested)

          if let tierString = school.priorityTier,
             let tier = PriorityTier(rawValue: tierString) {
            PriorityTierBadge(tier: tier)
          }

          if let size = school.size {
            SizeBadge(size: size)
          }

          if let conference = school.conference {
            ConferenceBadge(conference: conference)
          }
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityLabel("School details badges")
      .accessibilityHint("Swipe to navigate through school attributes")
    }
    .padding()
    .background(Color(.systemBackground))
  }
}

// MARK: - Badge Components

struct StatusBadge: View {
  let status: SchoolStatus

  var body: some View {
    let colors = status.badgeColors
    Text(status.displayName)
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(colors.background)
      .foregroundStyle(colors.text)
      .clipShape(Capsule())
      .accessibilityLabel("Status: \(status.displayName)")
  }
}

struct PriorityTierBadge: View {
  let tier: PriorityTier

  var body: some View {
    Text("Tier \(tier.displayName)")
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(tier.badgeColor.opacity(0.2))
      .foregroundStyle(tier.badgeColor)
      .clipShape(Capsule())
      .accessibilityLabel("Priority Tier \(tier.displayName)")
  }
}

struct DivisionBadge: View {
  let division: String

  var badgeColor: Color {
    switch division.uppercased() {
    case "D1": return .blue
    case "D2": return .green
    case "D3": return .purple
    case "NAIA": return .orange
    case "JUCO": return .gray
    default: return .gray
    }
  }

  var body: some View {
    Text(division.uppercased())
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(badgeColor.opacity(0.2))
      .foregroundStyle(badgeColor)
      .clipShape(Capsule())
      .accessibilityLabel("Division: \(division)")
  }
}

struct SizeBadge: View {
  let size: SchoolSize

  var body: some View {
    Text(size.displayName)
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(Color.gray.opacity(0.15))
      .foregroundStyle(.secondary)
      .clipShape(Capsule())
      .accessibilityLabel("Size: \(size.displayName)")
  }
}

struct ConferenceBadge: View {
  let conference: String

  var body: some View {
    Text(conference)
      .font(.caption)
      .fontWeight(.medium)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(Color.gray.opacity(0.1))
      .foregroundStyle(.secondary)
      .clipShape(Capsule())
      .accessibilityLabel("Conference: \(conference)")
  }
}

#Preview {
  SchoolDetailHeader(
    school: School(
      id: "1",
      userId: "user-1",
      name: "University of Texas at Austin",
      location: "Austin, TX",
      city: "Austin",
      state: "TX",
      division: "D1",
      conference: "Big 12",
      ranking: 5,
      isFavorite: true,
      website: nil,
      faviconUrl: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      ncaaId: nil,
      status: "recruited",
      statusChangedAt: nil,
      priorityTier: "A",
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
    ),
    onToggleFavorite: {}
  )
  .padding()
}
