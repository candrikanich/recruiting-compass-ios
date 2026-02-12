import SwiftUI

/// Reusable loading overlay for preference views
struct PreferenceLoadingOverlay: View {
  let isLoading: Bool
  let message: String

  var body: some View {
    Group {
      if isLoading {
        ProgressView(message)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color(.systemBackground).opacity(0.8))
          .accessibilityElement(children: .combine)
          .accessibilityLabel(message)
          .accessibilityAddTraits(.updatesFrequently)
      }
    }
  }
}

#Preview {
  ZStack {
    Color.gray.opacity(0.2)
    PreferenceLoadingOverlay(isLoading: true, message: "Loading preferences...")
  }
}
