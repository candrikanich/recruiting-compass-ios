import SwiftUI

struct SchoolCardView: View {
  let school: School
  let onToggleFavorite: () -> Void
  let onDelete: () -> Void

  @Environment(\.sizeCategory) private var sizeCategory

  private var initialsSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 56 : 48
  }

  private var initialsFont: Font {
    sizeCategory.isAccessibilityCategory ? .title2.bold() : .body.bold()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      headerSection
      badgesSection
      contentSection
      actionsSection
    }
    .padding(16)
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    .accessibilityElement(children: .contain)
  }

  // MARK: - Header

  private var headerSection: some View {
    HStack(spacing: 12) {
      schoolLogo
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(school.name)
          .font(.headline)
          .foregroundStyle(.primary)

        if let location = school.location {
          Text(location)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      FavoriteStarButton(isFavorite: school.isFavorite, action: onToggleFavorite)
    }
  }

  private var schoolLogo: some View {
    Group {
      if let faviconUrl = school.faviconUrl, let url = URL(string: faviconUrl) {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .scaledToFit()
          case .failure, .empty:
            initialsCircle
          @unknown default:
            initialsCircle
          }
        }
        .frame(width: initialsSize, height: initialsSize)
        .clipShape(RoundedRectangle(cornerRadius: 10))
      } else {
        initialsCircle
      }
    }
  }

  private var initialsCircle: some View {
    Text(school.initials)
      .font(initialsFont)
      .foregroundStyle(.white)
      .frame(width: initialsSize, height: initialsSize)
      .background(
        LinearGradient(
          colors: [.blueGradientStart, Color(hex: "7C3AED")],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  // MARK: - Badges

  private var badgesSection: some View {
    FlowLayout(spacing: 8) {
      if let division = school.division, let divisionEnum = Division(rawValue: division) {
        BadgeView(text: divisionEnum.displayName, color: divisionEnum.badgeColor)
      }

      if let statusEnum = SchoolStatus(rawValue: school.status) {
        BadgeView(text: statusEnum.displayName, color: statusEnum.badgeColor)
      }

      FitScoreBadge(score: school.fitScore)

      if let size = school.size {
        BadgeView(text: size.displayName, color: .gray)
      }
    }
  }

  // MARK: - Content

  private var contentSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let conference = school.conference {
        HStack(spacing: 8) {
          Image(systemName: "sportscourt")
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)

          Text(conference)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Conference: \(conference)")
      }

      if let notes = school.notes, !notes.isEmpty {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "note.text")
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)

          Text(notes)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        .accessibilityLabel("Notes: \(notes)")
      }
    }
  }

  // MARK: - Actions

  private var actionsSection: some View {
    HStack {
      Spacer()

      Button(role: .destructive, action: onDelete) {
        HStack(spacing: 4) {
          Image(systemName: "trash")
            .accessibilityHidden(true)
          Text("Delete")
        }
        .font(.subheadline)
        .fontWeight(.medium)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
      }
      .accessibilityLabel("Delete school")
      .accessibilityHint("Double tap to delete this school")
    }
  }
}

#Preview {
  let school = School(
    id: "1",
    userId: "user-1",
    name: "Stanford University",
    location: "Stanford, CA",
    city: "Stanford",
    state: "CA",
    division: "D1",
    conference: "Pac-12",
    ranking: 5,
    isFavorite: true,
    website: nil,
    faviconUrl: nil,
    twitterHandle: nil,
    instagramHandle: nil,
    ncaaId: nil,
    status: "interested",
    statusChangedAt: nil,
    priorityTier: "A",
    notes: "Great academic program",
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
    fitScore: 85,
    fitTier: nil,
    familyUnitId: "family-1",
    createdBy: nil,
    updatedBy: nil,
    createdAt: "2025-01-01T00:00:00Z",
    updatedAt: "2025-01-01T00:00:00Z"
  )

  SchoolCardView(
    school: school,
    onToggleFavorite: {},
    onDelete: {}
  )
  .padding()
}
