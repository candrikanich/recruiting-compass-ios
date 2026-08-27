import Foundation
import SwiftUI

/// Section builders for `PublicProfileCard`, split out to keep the main
/// view file focused on hero/layout logic. One method per `ProfileSectionKey`.
extension PublicProfileCard {
    // MARK: - 1. Verified Athletic Metrics

    @ViewBuilder
    var metricsSection: some View {
        sectionContainer(title: String(localized: "Verified Athletic Metrics"), icon: "chart.bar") {
            if credentialsRowVisible {
                FlowChips(chips: credentialsChips)
                    .padding(.bottom, 8)
            }
            if let metrics = data.metrics, !metrics.isEmpty {
                let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(metrics) { metric in metricCard(metric) }
                }
            } else {
                emptyStateText(String(localized: "No verified metrics yet"))
            }
        }
    }

    private var credentialsRowVisible: Bool {
        guard let credentials = data.credentials else { return false }
        return credentials.ncaaId != nil || !Self.v2ServiceRows(credentials).isEmpty
            || credentials.perfectGameId != nil || credentials.prepBaseballId != nil
    }

    /// NCAA ID pill + service badges (PBR / Perfect Game / v2 registry), Figma
    /// "credentials row" atop the metrics grid.
    private var credentialsChips: [String] {
        guard let credentials = data.credentials else { return [] }
        var chips: [String] = []
        if let ncaaId = credentials.ncaaId { chips.append(String(localized: "NCAA ID: \(ncaaId)")) }
        if let pgId = credentials.perfectGameId {
            let label = RecruitingServices.service(forKey: "perfect_game_id")?.label ?? "Perfect Game"
            chips.append("\(label) · \(pgId)")
        }
        if credentials.prepBaseballId != nil || Self.prepBaseballURL(credentials, playerName: data.playerName) != nil {
            let label = RecruitingServices.service(forKey: "prep_baseball_id")?.label ?? "Prep Baseball"
            chips.append(credentials.prepBaseballId.map { "\(label) · \($0)" } ?? label)
        }
        for entry in Self.v2ServiceRows(credentials) {
            chips.append(entry.def.linkKind == .url ? entry.def.label : "\(entry.def.label) · \(entry.value)")
        }
        return chips
    }

    private func metricCard(_ metric: PublicProfileData.MetricEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(metric.label.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.Text.muted)
                Spacer()
                if metric.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .accessibilityLabel(String(localized: "Verified"))
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(metric.value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.Text.primary)
                if !metric.unit.isEmpty {
                    Text(metric.unit)
                        .font(.caption)
                        .foregroundStyle(Color.Text.muted)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Surface.muted)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// Sport-gated v2 services the athlete has filled in, in registry order.
    static func v2ServiceRows(
        _ credentials: PublicProfileData.CredentialsRow
    ) -> [(def: RecruitingServices.ServiceDef, value: String)] {
        RecruitingServices.servicesForSport(credentials.primarySport)
            .compactMap { def in
                guard let raw = credentials.serviceValue(forKey: def.key)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !raw.isEmpty else { return nil }
                return (def, raw)
            }
    }

    static func prepBaseballURL(
        _ credentials: PublicProfileData.CredentialsRow, playerName: String
    ) -> String? {
        guard let def = RecruitingServices.service(forKey: "prep_baseball_id") else { return nil }
        return RecruitingServices.profileURL(
            for: def, value: credentials.prepBaseballId,
            state: credentials.prepBaseballState, name: playerName
        )
    }

    // MARK: - 2. Featured Highlights

    @ViewBuilder
    var filmSection: some View {
        sectionContainer(title: String(localized: "Featured Highlights"), icon: "film") {
            if let film = data.film, !film.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(film.enumerated()), id: \.offset) { _, item in
                        filmRow(item)
                    }
                }
            } else {
                emptyStateText(String(localized: "No highlights added yet"))
            }
        }
    }

    private func filmRow(_ item: PublicProfileData.FilmItem) -> some View {
        let label = item.title ?? item.url
        // No thumbnail URL exists in the data model yet (web + iOS both show a
        // placeholder card) — parity with web `HighlightsReel.vue`.
        return Group {
            if let url = URL(string: item.url) {
                Link(destination: url) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(Color.Surface.muted)
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.Text.muted)
                        }
                        .frame(width: 64, height: 40)
                        Text(label).font(.footnote.weight(.medium))
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.caption2)
                    }
                }
                .accessibilityLabel(String(localized: "Film link: \(label)"))
            } else {
                Text(label).font(.footnote).foregroundStyle(Color.Text.secondary)
            }
        }
    }

    // MARK: - 3. Academic Profile

    @ViewBuilder
    var academicsSection: some View {
        sectionContainer(title: String(localized: "Academic Profile"), icon: "graduationcap") {
            if let academics = data.academics {
                VStack(alignment: .leading, spacing: 6) {
                    if let highSchool = academics.highSchool {
                        detailRow(label: String(localized: "High School"), value: highSchool)
                    }
                    if let gpa = academics.gpa {
                        detailRow(label: String(localized: "GPA"), value: Self.formatGPA(gpa))
                    }
                    if let satScore = academics.satScore {
                        detailRow(label: String(localized: "SAT"), value: "\(satScore)")
                    }
                    if let actScore = academics.actScore {
                        detailRow(label: String(localized: "ACT"), value: "\(actScore)")
                    }
                    if let gradYear = academics.graduationYear {
                        detailRow(label: String(localized: "Graduation Year"), value: "\(gradYear)")
                    }
                    if let major = academics.intendedMajor, !major.isEmpty {
                        detailRow(label: String(localized: "Desired Major"), value: major)
                    }
                }
                if let ncaaId = data.credentials?.ncaaId {
                    Text(String(localized: "NCAA Eligibility Center ID: \(ncaaId)"))
                        .font(.caption)
                        .foregroundStyle(Color.Text.muted)
                        .padding(.top, 8)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.Surface.muted)
                        .clipShape(Capsule())
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
            } else {
                emptyStateText(String(localized: "No academic details yet"))
            }
        }
    }

    // MARK: - 4. Target Program & Values

    @ViewBuilder
    var valuesSection: some View {
        sectionContainer(title: String(localized: "Target Program & Values"), icon: "target") {
            if let lookingFor = data.lookingFor, !lookingFor.isEmpty {
                Text(lookingFor)
                    .font(.footnote)
                    .foregroundStyle(Color.Text.secondary)
            }
            if !data.valuesTags.isEmpty {
                FlowChips(chips: data.valuesTags)
                    .padding(.top, data.lookingFor?.isEmpty == false ? 8 : 0)
            }
            if (data.lookingFor?.isEmpty ?? true) && data.valuesTags.isEmpty {
                emptyStateText(String(localized: "Nothing shared yet"))
            }
        }
    }

    // MARK: - 5. Team History & Coaching References

    @ViewBuilder
    var teamHistorySection: some View {
        sectionContainer(title: String(localized: "Team History & Coaching References"), icon: "clock") {
            if let teamHistory = data.teamHistory, !teamHistory.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(teamHistory) { entry in teamHistoryRow(entry) }
                }
            } else {
                emptyStateText(String(localized: "No team history yet"))
            }
        }
    }

    private func teamHistoryRow(_ entry: PublicProfileData.TeamHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(entry.name).font(.footnote.weight(.semibold))
                Text(entry.level)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.Surface.muted)
                    .clipShape(Capsule())
                if let years = entry.years {
                    Text(years).font(.caption).foregroundStyle(Color.Text.muted)
                }
            }
            if let coach = entry.coach, !coach.isEmpty {
                let contactSuffix = entry.contact.map { " — Reference Contact: \($0)" } ?? ""
                Text("Coach: \(coach)\(contactSuffix)")
                    .font(.caption)
                    .foregroundStyle(Color.Text.secondary)
            }
        }
    }

    // MARK: - 6. Awards & Athletic Honors

    @ViewBuilder
    var awardsSection: some View {
        sectionContainer(title: String(localized: "Awards & Athletic Honors"), icon: "trophy") {
            if let awards = data.awards, !awards.isEmpty {
                FlowChips(awardChips: awards)
            } else {
                emptyStateText(String(localized: "No awards yet"))
            }
        }
    }

    // MARK: - Shared building blocks

    @ViewBuilder
    func sectionContainer<Content: View>(
        title: String, icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(title).font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: icon)
            }
            .foregroundStyle(Color.Text.primary)
            .accessibilityAddTraits(.isHeader)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Surface.muted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

    func emptyStateText(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Color.Text.muted)
    }
}

/// Minimal wrapping chip row for tag/credential/award chips (no external dependency).
struct FlowChips: View {
    let chips: [String]

    init(items: [String]) { self.chips = items }
    init(chips: [String]) { self.chips = chips }
    init(awardChips awards: [PublicProfileData.AwardEntry]) {
        self.chips = awards.map { award in
            award.year.map { "🏅 \(award.title) · \($0)" } ?? "🏅 \(award.title)"
        }
    }

    var body: some View {
        // Simple wrap using a LazyVGrid-free flex approach: horizontal
        // ScrollView keeps this lightweight and avoids a custom Layout.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(chips, id: \.self) { chip in
                    Text(chip)
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
        .accessibilityLabel(Text(chips.joined(separator: ", ")))
    }
}
