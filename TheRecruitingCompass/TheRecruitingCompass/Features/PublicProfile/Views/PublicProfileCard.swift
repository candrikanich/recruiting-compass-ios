import SwiftUI
import UIKit

/// Native coach-facing card for a player's public profile — the owner-side
/// preview shown in the Setup panel and used for PDF export. Mirrors
/// `recruiting-compass-web/components/profile/PublicProfileCard.vue` (Figma
/// parity, PRs #500–510): coach-bar, dark hero (photo/name/physicals/bio/
/// socials), then owner-ordered sections, then a footer.
///
/// The coach never opens this native view — coaches always follow the shared
/// web link, which renders the real `pages/p/[slug].vue`. This card exists so
/// the athlete/parent can preview what that page will look like, and to
/// render the PDF export.
struct PublicProfileCard: View {
    let data: PublicProfileData

    /// Pre-fetched header photo. Used by the PDF export, where `ImageRenderer` cannot await the
    /// async `AsyncImage` load — supplying a ready `UIImage` makes the photo draw synchronously.
    /// `nil` (the default, and the live on-screen preview) keeps the normal `AsyncImage` path.
    var photoOverride: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero

            VStack(alignment: .leading, spacing: 20) {
                ForEach(pairedSections, id: \.primary) { pair in
                    sectionRow(for: pair)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)

            footer
        }
        .background(Color.Surface.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.Surface.border, lineWidth: 1)
        )
    }

    // MARK: - Section ordering / pairing

    /// One row to render: a lone section, or a (primary, paired) 2-col pair.
    /// Mirrors web's academics+values and team_history+awards pairing —
    /// the paired key is dropped from its own standalone slot.
    struct SectionRow: Equatable {
        let primary: ProfileSectionKey
        let paired: ProfileSectionKey?
    }

    private var pairedSections: [SectionRow] { Self.pairedSections(for: data.visibleSectionOrder) }

    /// Pure, unit-testable pairing logic — academics pairs with values (when
    /// both visible) and the standalone `values` slot is dropped; team_history
    /// pairs with awards the same way. Byte-parity with web
    /// `PublicProfileCard.vue`'s `academicsVisible`/`valuesVisible`/
    /// `teamHistoryVisible`/`awardsVisible` computeds.
    static func pairedSections(for order: [ProfileSectionKey]) -> [SectionRow] {
        let hasValues = order.contains(.values)
        let hasAwards = order.contains(.awards)
        var rows: [SectionRow] = []
        for key in order {
            switch key {
            case .academics:
                rows.append(SectionRow(primary: .academics, paired: hasValues ? .values : nil))
            case .values where hasValues && order.contains(.academics):
                continue // drawn paired with academics above
            case .teamHistory:
                rows.append(SectionRow(primary: .teamHistory, paired: hasAwards ? .awards : nil))
            case .awards where hasAwards && order.contains(.teamHistory):
                continue // drawn paired with team history above
            default:
                rows.append(SectionRow(primary: key, paired: nil))
            }
        }
        return rows
    }

    @ViewBuilder
    private func sectionRow(for row: SectionRow) -> some View {
        if let paired = row.paired {
            let columns = [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                section(for: row.primary)
                section(for: paired)
            }
        } else {
            section(for: row.primary)
        }
    }

    @ViewBuilder
    private func section(for key: ProfileSectionKey) -> some View {
        switch key {
        case .metrics: metricsSection
        case .film: filmSection
        case .academics: academicsSection
        case .values: valuesSection
        case .teamHistory: teamHistorySection
        case .awards: awardsSection
        }
    }

    // MARK: - Coach-bar + Hero

    @ViewBuilder
    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            coachBar
            heroBody
        }
        .background(data.headerColor.color)
    }

    @ViewBuilder
    private var coachBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "viewfinder.circle").accessibilityHidden(true)
                Text("RecruitingCompass").font(.footnote.weight(.semibold))
            }
            .foregroundStyle(.white)
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text(String(localized: "Verified Coach Access"))
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(Color.green.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.green.opacity(0.15))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
        }
    }

    @ViewBuilder
    private var heroBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                heroPhoto
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text(data.playerName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    if let sport = data.credentials?.primarySport, !sport.isEmpty {
                        Text(sport)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }

                if let physicals = physicalsLine {
                    Text(physicals)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                if let bio = data.bio {
                    Text(bio)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.85))
                }

                if let social = data.social, !social.isEmpty {
                    socialRowHero(social)
                }
            }

            heroActions
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var heroPhoto: some View {
        Group {
            if let photoOverride {
                Image(uiImage: photoOverride).resizable().scaledToFill()
            } else if let photoUrl = data.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.white.opacity(0.15)
                    }
                }
            } else {
                ZStack {
                    Color.white.opacity(0.15)
                    Text(String(data.playerName.prefix(1)))
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 112, height: 112)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 2))
        .accessibilityLabel(String(localized: "\(data.playerName) profile photo"))
    }

    /// `6'2" · 170 lbs · 3B/2B · Class of 2028 · 3.80 GPA` — parity with web
    /// `ProfileHero.vue` `physicals` computed.
    private var physicalsLine: String? {
        var parts: [String] = []
        if let heightInches = data.credentials?.heightInches {
            parts.append(Self.formatHeight(heightInches))
        }
        if let weightLbs = data.credentials?.weightLbs {
            parts.append("\(weightLbs) lbs")
        }
        let positionShort = CanonicalPositions.formatPositionsShort(
            sport: data.credentials?.primarySport,
            positions: data.credentials?.positions,
            fallback: data.credentials?.primaryPosition)
        if !positionShort.isEmpty { parts.append(positionShort) }
        if let gradYear = data.academics?.graduationYear {
            parts.append(String(localized: "Class of \(gradYear)"))
        }
        if let gpa = data.academics?.gpa {
            parts.append(String(localized: "\(Self.formatGPA(gpa)) GPA"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func socialRowHero(_ social: PublicProfileData.SocialSection) -> some View {
        let links = SocialLinkBuilder.brandLinks(from: social)
        return HStack(spacing: 6) {
            ForEach(Array(links.enumerated()), id: \.offset) { index, link in
                if index > 0 {
                    Text("·").foregroundStyle(.white.opacity(0.4))
                }
                Link(destination: link.url) {
                    HStack(spacing: 4) {
                        Image(systemName: link.systemImage).font(.caption2)
                        Text(link.handle).font(.caption)
                    }
                }
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityLabel(String(localized: "\(link.platform) \(link.handle)"))
            }
        }
    }

    /// Contact/Express Interest are visual-only in this native preview — the
    /// coach always submits leads via the real web page, never this in-app
    /// card, so there is no iOS-side lead endpoint to wire these to.
    @ViewBuilder
    private var heroActions: some View {
        HStack(spacing: 12) {
            Label(String(localized: "Contact Player"), systemImage: "envelope")
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                .foregroundStyle(.white)

            Label(String(localized: "Express Interest"), systemImage: "star.fill")
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
        .accessibilityHidden(true) // decorative preview only, not interactive
    }

    // MARK: - Footer

    @ViewBuilder
    var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(String(localized: "Powered by The Recruiting Compass"), systemImage: "viewfinder.circle")
                    .font(.caption)
                    .foregroundStyle(Color.Text.muted)
                Spacer()
                if let social = data.social, !social.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(SocialLinkBuilder.brandLinks(from: social), id: \.platform) { link in
                            Link(destination: link.url) {
                                Image(systemName: link.systemImage)
                            }
                            .foregroundStyle(Color.Text.muted)
                            .accessibilityLabel(link.platform)
                        }
                    }
                }
            }
            if let updatedAt = data.updatedAt {
                Text(String(localized: "Profile last updated: \(Self.footerDateFormatter.string(from: updatedAt))"))
                    .font(.caption2)
                    .foregroundStyle(Color.Text.muted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.Surface.muted)
    }

    static let footerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func formatHeight(_ inches: Int) -> String {
        let feet = inches / 12
        let remainder = inches % 12
        return "\(feet)'\(remainder)\""
    }

    static func formatGPA(_ gpa: Double) -> String {
        String(format: "%.2f", gpa)
    }
}
