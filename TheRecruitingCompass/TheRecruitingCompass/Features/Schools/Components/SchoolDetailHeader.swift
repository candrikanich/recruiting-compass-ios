import SwiftUI

struct SchoolDetailHeader: View {
  let school: School
  let onToggleFavorite: () -> Void

  @Environment(\.sizeCategory) private var sizeCategory

  private var displayLocation: String? {
    if let location = school.location, !location.isEmpty {
      return location
    }
    let cityState = [school.city, school.state].compactMap { $0 }.filter { !$0.isEmpty }
    if !cityState.isEmpty {
      return cityState.joined(separator: ", ")
    }
    if let address = school.academicInfo?.address, !address.isEmpty {
      return address
    }
    if let state = school.state, !state.isEmpty {
      return state
    }
    return nil
  }

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
                .bold()
                .foregroundStyle(.blue)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12))
          } else {
            Text(school.initials)
              .font(.title2)
              .bold()
              .foregroundStyle(.blue)
          }
        }
        .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          Text(school.name)
            .font(.title2)
            .bold()
            .lineLimit(2)
            .minimumScaleFactor(0.9)

          if let location = displayLocation {
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
      }

      // Badges row
      ScrollView(.horizontal) {
        HStack(spacing: 8) {
          if let division = school.division {
            DivisionBadge(division: division)
          }

          StatusBadge(status: SchoolStatus(rawValue: school.status) ?? .interested)

          if let size = school.size {
            SizeBadge(size: size)
          }

          if let conference = school.conference {
            ConferenceBadge(conference: conference)
          }
        }
      }
      .scrollIndicators(.hidden)
      .accessibilityElement(children: .contain)
      .accessibilityLabel(String(localized: "School details badges"))
      .accessibilityHint("Swipe to navigate through school attributes")
    }
    .padding()
    .background(Color(.systemBackground))
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
      notes: nil,
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
