import SwiftUI

struct FitScoreSection: View {
  let fitScore: FitScoreResult
  @State private var isExpanded = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("School Fit Analysis")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)

        Spacer()
      }

      // Score and tier
      HStack(alignment: .center, spacing: 16) {
        // Large score display
        VStack(spacing: 4) {
          Text("\(Int(fitScore.score))")
            .font(.largeTitle)
            .bold()
            .foregroundStyle(fitScoreColor(fitScore.score))
            .accessibilityLabel("Fit score: \(Int(fitScore.score)) out of 100")

          Text("Fit Score")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)

        VStack(alignment: .leading, spacing: 8) {
          // Tier badge
          HStack(spacing: 6) {
            Circle()
              .fill(fitScore.tier.badgeColor.indicatorColor)
              .frame(width: 8, height: 8)
              .accessibilityHidden(true)

            Text(fitScore.tier.displayName)
              .font(.subheadline)
              .fontWeight(.semibold)
              .foregroundStyle(fitScore.tier.badgeColor.foregroundColor)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(fitScore.tier.badgeColor.backgroundColor)
          .clipShape(.rect(cornerRadius: 12))

          Text(fitScore.tier.description)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()

        // Expand/collapse button
        Button {
          if reduceMotion {
            isExpanded.toggle()
          } else {
            withAnimation { isExpanded.toggle() }
          }
        } label: {
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.title3)
            .foregroundStyle(.secondary)
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel(isExpanded ? String(localized: "Hide breakdown") : String(localized: "Show breakdown"))
      }

      // Breakdown (expandable)
      if isExpanded {
        VStack(spacing: 12) {
          Text("Breakdown")
            .font(.subheadline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)

          if let athletic = fitScore.breakdown.athleticFit {
            BreakdownRow(label: "Athletic Fit", score: athletic, color: Color.Brand.blue500)
          }
          if let academic = fitScore.breakdown.academicFit {
            BreakdownRow(label: "Academic Fit", score: academic, color: Color.Brand.purple500)
          }
          if let opportunity = fitScore.breakdown.opportunityFit {
            BreakdownRow(label: "Opportunity Fit", score: opportunity, color: Color.Brand.emerald500)
          }
          if let personal = fitScore.breakdown.personalFit {
            BreakdownRow(label: "Personal Fit", score: personal, color: Color.Brand.orange500)
          }

          if !fitScore.missingDimensions.isEmpty {
            HStack(spacing: 6) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
                .accessibilityHidden(true)

              Text("Missing data: \(fitScore.missingDimensions.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
          }
        }
        .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .clipShape(.rect(cornerRadius: 12))
  }

  private func fitScoreColor(_ score: Double) -> Color {
    if score >= 70 { return Color.Brand.emerald600 }
    if score >= 50 { return Color.Brand.orange600 }
    return Color.Brand.red600
  }
}

#Preview {
  ScrollView {
    FitScoreSection(
      fitScore: FitScoreResult(
        score: 75.5,
        tier: .match,
        breakdown: FitScoreBreakdown(
          athleticFit: 80,
          academicFit: 75,
          opportunityFit: 70,
          personalFit: 77
        ),
        missingDimensions: []
      )
    )
    .padding()
  }
}
