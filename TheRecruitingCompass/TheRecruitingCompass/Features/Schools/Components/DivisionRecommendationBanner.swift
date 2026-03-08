import SwiftUI

struct DivisionRecommendationBanner: View {
  let recommendation: DivisionRecommendation

  var body: some View {
    if recommendation.shouldConsiderOtherDivisions {
      HStack(spacing: 12) {
        Image(systemName: "info.circle.fill")
          .foregroundStyle(.blue)
          .font(.title3)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          Text("Consider Other Divisions")
            .font(.subheadline)
            .fontWeight(.semibold)

          Text(recommendation.message)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()
      }
      .padding()
      .background(Color.blue.opacity(0.1))
      .clipShape(.rect(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.blue.opacity(0.3), lineWidth: 1)
      )
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Division recommendation: \(recommendation.message)")
    }
  }
}

#Preview {
  DivisionRecommendationBanner(
    recommendation: DivisionRecommendation(
      shouldConsiderOtherDivisions: true,
      recommendedDivisions: ["D2", "D3"],
      message: "Based on your fit score, you may want to consider schools in D2, D3."
    )
  )
  .padding()
}
