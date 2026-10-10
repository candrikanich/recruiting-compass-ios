import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "SchoolRecommendations")

struct SchoolRecommendationsWidget: View {
  let recommendations: [SchoolRecommendation]
  let onAdd: (SchoolRecommendation) -> Void
  let onDismiss: (SchoolRecommendation) -> Void

  @Environment(\.switchTab) private var switchTab

  var body: some View {
    if !recommendations.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        header

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12) {
            ForEach(recommendations) { rec in
              recommendationCard(rec)
            }
          }
          .padding(.horizontal, 1) // Prevent shadow clipping
        }
      }
      .padding()
      .background(Color.Surface.card)
      .clipShape(.rect(cornerRadius: 12))
      .brandShadowSm()
    }
  }

  // MARK: - Header

  @ViewBuilder
  private var header: some View {
    HStack {
      HStack(spacing: 8) {
        Image(systemName: "sparkles")
          .foregroundStyle(Color.amberGold)
          .accessibilityHidden(true)

        Text("Recommended Schools")
          .font(.brand(.headline))
          .accessibilityAddTraits(.isHeader)
      }

      Spacer()

      Button {
        switchTab(.schools)
      } label: {
        HStack(spacing: 4) {
          Text("See all")
            .font(.brand(.caption))
          Image(systemName: "chevron.right")
            .font(.brand(.caption2))
            .accessibilityHidden(true)
        }
        .foregroundStyle(Color.accentPrimary)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(String(localized: "See all schools"))
    }
  }

  // MARK: - Recommendation Card

  @ViewBuilder
  private func recommendationCard(_ rec: SchoolRecommendation) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(rec.name)
        .font(.brand(.subheadline, weight: .semibold))
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 6) {
        if let division = rec.division {
          Text(division)
            .font(.brand(.caption2, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentPrimary.opacity(0.12))
            .foregroundStyle(Color.accentPrimary)
            .clipShape(.capsule)
        }

        if let state = rec.state {
          Text(state)
            .font(.brand(.caption2))
            .foregroundStyle(Color.secondaryText)
        }
      }

      if let reason = rec.reasons.first {
        Text(reason)
          .font(.brand(.caption))
          .foregroundStyle(Color.secondaryText)
          .lineLimit(2)
      }

      Spacer()

      HStack(spacing: 8) {
        Button {
          onAdd(rec)
        } label: {
          Text("Add")
            .font(.brand(.caption, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 32)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel(String(localized: "Add \(rec.name)"))

        Button {
          onDismiss(rec)
        } label: {
          Text("Skip")
            .font(.brand(.caption, weight: .medium))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 32)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(String(localized: "Dismiss \(rec.name)"))
      }
    }
    .padding(12)
    .frame(width: 180, alignment: .leading)
    .background(Color.Surface.border.opacity(0.2))
    .clipShape(.rect(cornerRadius: 10))
    .accessibilityElement(children: .contain)
  }
}

#Preview {
  SchoolRecommendationsWidget(
    recommendations: [
      SchoolRecommendation(
        catalogKey: "ohio-state",
        name: "Ohio State University",
        division: "D1",
        conference: "Big Ten",
        state: "OH",
        score: 0.85,
        reasons: ["Strong baseball program"]
      ),
      SchoolRecommendation(
        catalogKey: "michigan",
        name: "University of Michigan",
        division: "D1",
        conference: "Big Ten",
        state: "MI",
        score: 0.82,
        reasons: ["Good academic fit"]
      ),
      SchoolRecommendation(
        catalogKey: "duke",
        name: "Duke University",
        division: "D1",
        conference: "ACC",
        state: "NC",
        score: 0.78,
        reasons: ["Matches your campus preference"]
      )
    ],
    onAdd: { _ in },
    onDismiss: { _ in }
  )
  .padding()
}
