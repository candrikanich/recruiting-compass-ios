import SwiftUI

struct SchoolCardView: View {
  let school: School
  let onToggleFavorite: () -> Void
  var onDelete: () -> Void = {}

  @Environment(\.sizeCategory) private var sizeCategory

  var deleteAccessibilityLabel: String { String(localized: "Delete \(school.name)") }

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
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.Surface.card)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color(uiColor: .separator), lineWidth: 1)
    )
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
    .accessibilityElement(children: .contain)
  }

  // MARK: - Header

  @ViewBuilder
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

      deleteButton
    }
  }

  @ViewBuilder
  private var deleteButton: some View {
    Button(role: .destructive, action: onDelete) {
      Image(systemName: "trash")
        .font(.subheadline)
        .foregroundStyle(Color.errorRed)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }
    .accessibilityLabel(deleteAccessibilityLabel)
    .accessibilityHint("Double tap to delete this school")
  }

  @ViewBuilder
  private var schoolLogo: some View {
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

  @ViewBuilder
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

  @ViewBuilder
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
        BadgeView(text: size.displayName, color: .slate)
      }
    }
  }

  // MARK: - Content

  @ViewBuilder
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
        .accessibilityLabel(String(localized: "Conference: \(conference)"))
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
        .accessibilityLabel(String(localized: "Notes: \(notes)"))
      }
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
    notes: "Great academic program",
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
    onToggleFavorite: {}
  )
  .padding()
}
