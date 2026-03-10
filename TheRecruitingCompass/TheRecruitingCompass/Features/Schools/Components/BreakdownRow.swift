import SwiftUI

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
