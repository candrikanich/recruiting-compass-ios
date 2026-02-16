import SwiftUI

struct ChartEmptyStateView: View {
  let iconName: String
  let message: String

  var body: some View {
    HStack {
      Spacer()
      VStack(spacing: 8) {
        Image(systemName: iconName)
          .font(.title)
          .foregroundStyle(Color.iconGray)
          .accessibilityHidden(true)
        Text(message)
          .font(.subheadline)
          .foregroundStyle(Color.secondaryText)
      }
      .padding(.vertical, 24)
      Spacer()
    }
  }
}
