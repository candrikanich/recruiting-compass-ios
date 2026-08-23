import Foundation
import SwiftUI

/// Section builders for `PublicProfileCard`, split out to keep the main
/// view file focused on layout/header logic.
extension PublicProfileCard {
    // MARK: - Athletic

    @ViewBuilder
    func athleticSection(_ athletic: PublicProfileData.AthleticSection) -> some View {
        sectionContainer(title: String(localized: "Athletic Profile")) {
            if let positions = athletic.positions, !positions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Positions")
                        .font(.caption)
                        .foregroundStyle(Color.Text.muted)

                    FlowChips(items: positions)
                }
                .padding(.bottom, 8)
            }

            VStack(alignment: .leading, spacing: 6) {
                if let heightInches = athletic.heightInches {
                    detailRow(label: String(localized: "Height"), value: Self.formatHeight(heightInches))
                }
                if let weightLbs = athletic.weightLbs {
                    detailRow(label: String(localized: "Weight"), value: "\(weightLbs) lbs")
                }
            }

            let prepBaseballURL = Self.prepBaseballURL(athletic, playerName: data.playerName)
            if athletic.ncaaId != nil || athletic.perfectGameId != nil
                || athletic.prepBaseballId != nil || prepBaseballURL != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recruiting IDs")
                        .font(.caption)
                        .foregroundStyle(Color.Text.muted)

                    if let ncaaId = athletic.ncaaId {
                        detailRow(label: String(localized: "NCAA ID"), value: ncaaId)
                    }
                    if let perfectGameId = athletic.perfectGameId {
                        perfectGameRow(perfectGameId)
                    }
                    if athletic.prepBaseballId != nil || prepBaseballURL != nil {
                        prepBaseballRow(id: athletic.prepBaseballId, urlString: prepBaseballURL)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func perfectGameRow(_ id: String) -> some View {
        let service = RecruitingServices.service(forKey: "perfect_game_id")
        let label = service?.label ?? String(localized: "Perfect Game")
        let urlString = (service?.urlTemplate ?? "https://www.perfectgame.org/Players/Playerprofile.aspx?ID={value}")
            .replacingOccurrences(of: "{value}", with: id)
        return HStack {
            Text(label)
                .font(.footnote)
                .foregroundStyle(Color.Text.muted)
            Spacer()
            if let url = URL(string: urlString) {
                Link(id, destination: url)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .accessibilityLabel(String(localized: "Perfect Game profile \(id)"))
            } else {
                Text(id)
                    .font(.footnote)
                    .fontWeight(.medium)
            }
        }
    }

    /// Resolve the slug-based Prep Baseball Report URL from the athlete's PBR
    /// state + display name — the canonical, byte-identical-with-web builder.
    static func prepBaseballURL(
        _ athletic: PublicProfileData.AthleticSection, playerName: String
    ) -> String? {
        guard let def = RecruitingServices.service(forKey: "prep_baseball_id") else { return nil }
        return RecruitingServices.profileURL(
            for: def, value: athletic.prepBaseballId,
            state: athletic.prepBaseballState, name: playerName
        )
    }

    private func prepBaseballRow(id: String?, urlString: String?) -> some View {
        let label = RecruitingServices.service(forKey: "prep_baseball_id")?.label
            ?? String(localized: "Prep Baseball")
        return HStack {
            Text(label)
                .font(.footnote)
                .foregroundStyle(Color.Text.muted)
            Spacer()
            if let urlString, let url = URL(string: urlString) {
                Link(id ?? String(localized: "View profile"), destination: url)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .accessibilityLabel(String(localized: "Prep Baseball Report profile"))
            } else if let id {
                Text(id)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Text.primary)
            }
        }
    }

    // MARK: - Academics

    @ViewBuilder
    func academicsSection(_ academics: PublicProfileData.AcademicsSection) -> some View {
        sectionContainer(title: String(localized: "Academics")) {
            VStack(alignment: .leading, spacing: 6) {
                if let gpa = academics.gpa {
                    detailRow(label: String(localized: "GPA"), value: Self.formatGPA(gpa))
                }
                if let graduationYear = academics.graduationYear {
                    detailRow(label: String(localized: "Grad Year"), value: "\(graduationYear)")
                }
                if let satScore = academics.satScore {
                    detailRow(label: String(localized: "SAT"), value: "\(satScore)")
                }
                if let actScore = academics.actScore {
                    detailRow(label: String(localized: "ACT"), value: "\(actScore)")
                }
                if let highSchool = academics.highSchool {
                    detailRow(label: String(localized: "High School"), value: highSchool)
                }
            }

            if let coreCourses = academics.coreCourses, !coreCourses.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Core Courses")
                        .font(.caption)
                        .foregroundStyle(Color.Text.muted)
                    Text(coreCourses.joined(separator: ", "))
                        .font(.footnote)
                        .foregroundStyle(Color.Text.secondary)
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Film

    @ViewBuilder
    func filmSection(_ film: [PublicProfileData.FilmItem]) -> some View {
        if !film.isEmpty {
            sectionContainer(title: String(localized: "Film")) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(film.enumerated()), id: \.offset) { _, item in
                        filmRow(item)
                    }
                }
            }
        }
    }

    private func filmRow(_ item: PublicProfileData.FilmItem) -> some View {
        let label = item.title ?? item.url
        return Group {
            if let url = URL(string: item.url) {
                Link(destination: url) {
                    Text(label)
                        .font(.footnote)
                        .fontWeight(.medium)
                }
                .accessibilityLabel(String(localized: "Film link: \(label)"))
            } else {
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(Color.Text.secondary)
            }
        }
    }

    // MARK: - Schools

    @ViewBuilder
    func schoolsSection(_ schools: [PublicProfileData.SchoolItem]) -> some View {
        if !schools.isEmpty {
            sectionContainer(title: String(localized: "Target Schools")) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(schools, id: \.id) { school in
                        Text(school.name)
                            .font(.footnote)
                            .foregroundStyle(Color.Text.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Social

    @ViewBuilder
    func socialSection(_ social: PublicProfileData.SocialSection) -> some View {
        if !social.isEmpty {
            sectionContainer(title: String(localized: "Social")) {
                VStack(alignment: .leading, spacing: 8) {
                    socialRow(label: String(localized: "Twitter"), handle: social.twitterHandle,
                              url: SocialLinkBuilder.twitterURL(social.twitterHandle))
                    socialRow(label: String(localized: "Instagram"), handle: social.instagramHandle,
                              url: SocialLinkBuilder.instagramURL(social.instagramHandle))
                    socialRow(label: String(localized: "TikTok"), handle: social.tiktokHandle,
                              url: SocialLinkBuilder.tiktokURL(social.tiktokHandle))
                    socialRow(label: String(localized: "Facebook"), handle: social.facebookUrl,
                              url: SocialLinkBuilder.facebookURL(social.facebookUrl))
                }
            }
        }
    }

    @ViewBuilder
    private func socialRow(label: String, handle: String?, url: URL?) -> some View {
        if let handle, !handle.trimmingCharacters(in: .whitespaces).isEmpty {
            HStack {
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(Color.Text.muted)
                Spacer()
                if let url {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Text(handle)
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                        }
                        .font(.footnote)
                        .fontWeight(.medium)
                    }
                    .accessibilityLabel(String(localized: "Open \(label) profile \(handle)"))
                } else {
                    Text(handle)
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.Text.primary)
                }
            }
        }
    }

    // MARK: - Shared building blocks

    @ViewBuilder
    func sectionContainer<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Text.muted)
                .accessibilityAddTraits(.isHeader)

            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.Surface.border)
                .frame(height: 1)
        }
    }

    func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.footnote)
                .foregroundStyle(Color.Text.muted)
            Spacer()
            Text(value)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(Color.Text.primary)
        }
    }

    static func formatHeight(_ inches: Int) -> String {
        let feet = inches / 12
        let remainder = inches % 12
        return "\(feet)'\(remainder)\""
    }

    static func formatGPA(_ gpa: Double) -> String {
        String(format: "%.2f", gpa)
    }
}

/// Minimal wrapping chip row for position tags (no external dependency).
private struct FlowChips: View {
    let items: [String]

    var body: some View {
        // Simple wrap using a LazyVGrid-free flex approach: horizontal
        // ScrollView keeps this lightweight and avoids a custom Layout.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.Surface.muted)
                        .foregroundStyle(Color.Text.secondary)
                        .clipShape(Capsule())
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Positions: \(items.joined(separator: ", "))"))
    }
}
