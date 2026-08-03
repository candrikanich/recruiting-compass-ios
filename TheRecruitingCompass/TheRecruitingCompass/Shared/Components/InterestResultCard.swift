import SwiftUI

/// Displays the result of interest calibration with visual feedback
struct InterestResultCard: View {
  let level: InterestLevel
  let description: String?

  init(level: InterestLevel, description: String? = nil) {
    self.level = level
    self.description = description ?? InterestCalibration().resultDescription
  }

  var body: some View {
    HStack(spacing: 12) {
      Text(level.emoji)
        .font(.title)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(level.displayName)
          .font(.headline)
          .foregroundStyle(level.badgeColor.foregroundColor)

        if let description {
          Text(description)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()
    }
    .padding()
    .background(level.badgeColor.backgroundColor.opacity(0.1))
    .clipShape(.rect(cornerRadius: 8))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Interest level: \(level.displayName). \(description ?? "")")
  }
}

#Preview {
  VStack(spacing: 16) {
    InterestResultCard(
      level: .high,
      description: "Strong interest indicated"
    )

    InterestResultCard(
      level: .medium,
      description: "Moderate interest shown"
    )

    InterestResultCard(
      level: .low,
      description: "Limited interest detected"
    )

    InterestResultCard(
      level: .notSet
    )
  }
  .padding()
}
