import SwiftUI

/// Native coach-facing card for a player's public profile. Mirrors
/// `recruiting-compass-web/components/profile/PublicProfileCard.vue`:
/// gradient header (photo + name + sport/position + bio), then conditional
/// Athletic / Academics / Film / Schools sections, then a footer.
struct PublicProfileCard: View {
    let data: PublicProfileData

    enum Section: CaseIterable {
        case athletic, academics, film, schools, social
    }

    /// Pure gating logic, unit-testable without rendering the view.
    static func visibleSections(for data: PublicProfileData) -> Set<Section> {
        var sections = Set<Section>()
        if data.athletic != nil { sections.insert(.athletic) }
        if data.academics != nil { sections.insert(.academics) }
        if data.film != nil { sections.insert(.film) }
        if data.schools != nil { sections.insert(.schools) }
        if let social = data.social, !social.isEmpty { sections.insert(.social) }
        return sections
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if let athletic = data.athletic { athleticSection(athletic) }
            if let academics = data.academics { academicsSection(academics) }
            if let film = data.film { filmSection(film) }
            if let schools = data.schools { schoolsSection(schools) }
            if let social = data.social { socialSection(social) }

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

    @ViewBuilder
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

    /// Header subtitle: `Grad Year · Primary Sport · Positions (abbrev) · GPA`.
    /// Each segment is optional; missing pieces are dropped, not shown blank.
    private var sportPositionLine: String? {
        var parts: [String] = []

        if let gradYear = data.academics?.graduationYear {
            parts.append(String(gradYear))
        }
        if let sport = data.athletic?.primarySport {
            parts.append(sport)
        }
        // Coach-facing primary/secondary only (e.g. "3B/SS") from the entered,
        // ordered positions[]; not the full list.
        let positionShort = CanonicalPositions.formatPositionsShort(
            sport: data.athletic?.primarySport,
            positions: data.athletic?.positions,
            fallback: data.athletic?.primaryPosition)
        if !positionShort.isEmpty {
            parts.append(positionShort)
        }
        if let gpa = data.academics?.gpa {
            parts.append(String(format: "%.2f GPA", gpa))
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Footer

    @ViewBuilder
    var footer: some View {
        Text("Powered by The Recruiting Compass")
            .font(.caption)
            .foregroundStyle(Color.Text.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.Surface.muted)
    }
}
