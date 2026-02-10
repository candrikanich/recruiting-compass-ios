import SwiftUI

struct FitScoreSection: View {
  let fitScore: FitScoreResult
  @State private var isExpanded = false

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
            .font(.system(size: 48, weight: .bold))
            .foregroundStyle(fitScoreColor(fitScore.score))

          Text("Fit Score")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        VStack(alignment: .leading, spacing: 8) {
          // Tier badge
          HStack(spacing: 6) {
            Circle()
              .fill(fitScore.tier.badgeColors.background)
              .frame(width: 8, height: 8)
              .accessibilityHidden(true)

            Text(fitScore.tier.displayName)
              .font(.subheadline)
              .fontWeight(.semibold)
              .foregroundStyle(fitScore.tier.badgeColors.text)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(fitScore.tier.badgeColors.background)
          .cornerRadius(12)

          Text(fitScore.tier.description)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()

        // Expand/collapse button
        Button {
          withAnimation {
            isExpanded.toggle()
          }
        } label: {
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.title3)
            .foregroundStyle(.secondary)
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel(isExpanded ? "Hide breakdown" : "Show breakdown")
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
            BreakdownRow(label: "Athletic Fit", score: athletic, color: .blue)
          }
          if let academic = fitScore.breakdown.academicFit {
            BreakdownRow(label: "Academic Fit", score: academic, color: .green)
          }
          if let opportunity = fitScore.breakdown.opportunityFit {
            BreakdownRow(label: "Opportunity Fit", score: opportunity, color: .orange)
          }
          if let personal = fitScore.breakdown.personalFit {
            BreakdownRow(label: "Personal Fit", score: personal, color: .purple)
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
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }

  private func fitScoreColor(_ score: Double) -> Color {
    switch score {
    case 80...: return .green
    case 60..<80: return .blue
    case 40..<60: return .orange
    default: return .red
    }
  }
}

struct BreakdownRow: View {
  let label: String
  let score: Double
  let color: Color

  var body: some View {
    VStack(spacing: 6) {
      HStack {
        Text(label)
          .font(.caption)
          .foregroundStyle(.secondary)

        Spacer()

        Text("\(Int(score))")
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundStyle(color)
      }

      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          // Background
          RoundedRectangle(cornerRadius: 4)
            .fill(Color(.systemGray5))
            .frame(height: 6)

          // Progress
          RoundedRectangle(cornerRadius: 4)
            .fill(color.gradient)
            .frame(width: geometry.size.width * (score / 100), height: 6)
        }
      }
      .frame(height: 6)
      .accessibilityLabel("\(label): \(Int(score)) out of 100")
      .accessibilityValue("\(Int(score)) percent")
    }
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
