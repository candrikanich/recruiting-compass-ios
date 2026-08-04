import SwiftUI

// MARK: - Download Fallback

struct DownloadFallbackView: View {
  let url: String
  let title: String

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "arrow.down.circle")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text("Preview not available for this file type")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      if let downloadURL = URL(string: url) {
        Link(destination: downloadURL) {
          Label("Download to view", systemImage: "arrow.down")
            .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Download to view")
        .accessibilityHint("Opens the file in the default app")
      }
    }
    .frame(maxWidth: .infinity)
    .padding(32)
  }
}
