import SwiftUI

/// Native coach-facing card for a player's public profile. Mirrors
/// `recruiting-compass-web/components/profile/PublicProfileCard.vue`:
/// gradient header (photo + name + sport/position + bio), then conditional
/// Athletic / Academics / Film / Schools sections, then a footer.
struct PublicProfileCard: View {
    let data: PublicProfileData

    enum Section: CaseIterable {
        case athletic, academics, film, schools
    }

    /// Pure gating logic, unit-testable without rendering the view.
    static func visibleSections(for data: PublicProfileData) -> Set<Section> {
        var sections = Set<Section>()
        if data.athletic != nil { sections.insert(.athletic) }
        if data.academics != nil { sections.insert(.academics) }
        if data.film != nil { sections.insert(.film) }
        if data.schools != nil { sections.insert(.schools) }
        return sections
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if let athletic = data.athletic { athleticSection(athletic) }
            if let academics = data.academics { academicsSection(academics) }
            if let film = data.film { filmSection(film) }
            if let schools = data.schools { schoolsSection(schools) }

            footer
        }
        .background(Color.Surface.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.Surface.border, lineWidth: 1)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            headerPhoto

            VStack(alignment: .leading, spacing: 4) {
                Text(data.playerName)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                if let sportLine = sportPositionLine {
                    Text(sportLine)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }

                if let bio = data.bio {
                    Text(bio)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.top, 4)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [data.headerColor.color, data.headerColor.color.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    @ViewBuilder
    private var headerPhoto: some View {
        if let photoUrl = data.photoUrl, let url = URL(string: photoUrl) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
            .accessibilityLabel(String(localized: "\(data.playerName) profile photo"))
        }
    }

    private var sportPositionLine: String? {
        guard let sport = data.athletic?.primarySport else { return nil }
        if let position = data.athletic?.primaryPosition {
            return "\(sport) · \(position)"
        }
        return sport
    }

    // MARK: - Footer

    var footer: some View {
        Text("Powered by The Recruiting Compass")
            .font(.caption)
            .foregroundStyle(Color.Text.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.Surface.muted)
    }
}
