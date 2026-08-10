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

            if athletic.ncaaId != nil || athletic.perfectGameId != nil || athletic.prepBaseballId != nil {
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
                    if let prepBaseballId = athletic.prepBaseballId {
                        detailRow(label: String(localized: "Prep Baseball"), value: prepBaseballId)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func perfectGameRow(_ id: String) -> some View {
        let urlString = "https://www.perfectgame.org/Players/Playerprofile.aspx?ID=\(id)"
        return HStack {
            Text("Perfect Game")
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
