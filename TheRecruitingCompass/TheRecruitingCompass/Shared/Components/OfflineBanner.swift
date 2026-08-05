import SwiftUI

/// Thin banner shown when the app is offline. Use with NetworkMonitor.isConnected.
struct OfflineBanner: View {
  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "wifi.slash")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.white)
        .accessibilityHidden(true)
      Text("No internet connection")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.white)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .background(Color.secondaryText)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "No internet connection"))
  }
}

#Preview {
  VStack {
    OfflineBanner()
    Spacer()
  }
}
