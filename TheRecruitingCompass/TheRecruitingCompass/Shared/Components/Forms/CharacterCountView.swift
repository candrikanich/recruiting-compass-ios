import SwiftUI

/// Displays character count with color coding based on proximity to limit
struct CharacterCountView: View {
  let currentCount: Int
  let maxCount: Int
  let warningThreshold: Double = 0.9 // Show when 90% full

  private var isOverLimit: Bool {
    currentCount > maxCount
  }

  private var showWarning: Bool {
    Double(currentCount) >= Double(maxCount) * warningThreshold
  }

  var body: some View {
    Text("\(currentCount)/\(maxCount)")
      .font(.caption)
      .foregroundStyle(isOverLimit ? .red : (showWarning ? .orange : .secondary))
      .accessibilityLabel("\(currentCount) of \(maxCount) characters")
      .accessibilityValue(isOverLimit ? "Limit exceeded" : "")
  }
}

#Preview("Character Count Examples") {
  VStack(spacing: 16) {
    CharacterCountView(currentCount: 100, maxCount: 500)
    CharacterCountView(currentCount: 460, maxCount: 500)
    CharacterCountView(currentCount: 520, maxCount: 500)
  }
  .padding()
}
