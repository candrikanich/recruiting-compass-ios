import SwiftUI

struct DocumentErrorBanner: View {
  let error: String
  let onRetry: () -> Void

  var body: some View {
    HStack {
      Text(error)
        .font(.brand(.caption))
        .foregroundStyle(.white)
      Spacer()
      Button("Retry", action: onRetry)
        .font(.brand(.caption))
        .foregroundStyle(.white)
    }
    .padding()
    .background(Color.errorRed)
    .clipShape(.rect(cornerRadius: 8))
  }
}
