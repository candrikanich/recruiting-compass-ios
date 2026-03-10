import SwiftUI

struct DocumentErrorBanner: View {
  let error: String
  let onRetry: () -> Void

  var body: some View {
    HStack {
      Text(error)
        .font(.caption)
        .foregroundStyle(.white)
      Spacer()
      Button("Retry", action: onRetry)
        .font(.caption)
        .foregroundStyle(.white)
    }
    .padding()
    .background(Color.errorRed)
    .clipShape(.rect(cornerRadius: 8))
  }
}
