import SwiftUI

struct ResponsivenessBar: View {
  let score: Double

  @Environment(\.sizeCategory) private var sizeCategory

  private var normalizedScore: Double {
    min(max(score, 0), 100)
  }

  private var barColor: Color {
    if normalizedScore >= 75 {
      return .successGreen
    } else if normalizedScore >= 50 {
      return .amberGold
    } else {
      return .errorRed
    }
  }

  private var accessibilityLabel: String {
    "\(Int(normalizedScore))% Responsive"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 3)
            .fill(Color.borderGray.opacity(0.3))
            .frame(height: 6)

          RoundedRectangle(cornerRadius: 3)
            .fill(barColor)
            .frame(width: geometry.size.width * normalizedScore / 100, height: 6)
        }
      }
      .frame(height: 6)
      .accessibilityHidden(true)

      Text(accessibilityLabel)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Responsiveness")
    .accessibilityValue(accessibilityLabel)
    .accessibilityAddTraits(.updatesFrequently)
  }
}

#Preview {
  VStack(spacing: 20) {
    ResponsivenessBar(score: 90)
    ResponsivenessBar(score: 60)
    ResponsivenessBar(score: 30)
  }
  .padding()
}
