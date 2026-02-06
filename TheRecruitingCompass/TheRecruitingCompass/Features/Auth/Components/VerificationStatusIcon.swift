import SwiftUI

struct VerificationStatusIcon: View {
  let state: VerificationState
  @State private var isAnimating = false

  var body: some View {
    ZStack {
      // Background circle
      Circle()
        .fill(backgroundColor)
        .frame(width: 80, height: 80)

      // Icon content
      Group {
        switch state {
        case .pending:
          Image(systemName: "envelope.fill")
            .font(.system(size: 40))
            .foregroundColor(Color(red: 0.855, green: 0.620, blue: 0.118))

        case .checking:
          ProgressView()
            .tint(Color(red: 0.149, green: 0.388, blue: 0.931))
            .scaleEffect(1.5)

        case .verified:
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 40))
            .foregroundColor(Color(red: 0.2, green: 0.62, blue: 0.4))
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isAnimating)

        case .error:
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 40))
            .foregroundColor(Color.red)
        }
      }
    }
    .onAppear {
      if case .verified = state {
        isAnimating = true
      }
    }
  }

  private var backgroundColor: Color {
    switch state {
    case .pending:
      return Color(red: 0.855, green: 0.620, blue: 0.118).opacity(0.15)
    case .checking:
      return Color(red: 0.149, green: 0.388, blue: 0.931).opacity(0.15)
    case .verified:
      return Color(red: 0.2, green: 0.62, blue: 0.4).opacity(0.15)
    case .error:
      return Color.red.opacity(0.15)
    }
  }
}

#Preview {
  VStack(spacing: 32) {
    VerificationStatusIcon(state: .pending)
    VerificationStatusIcon(state: .checking)
    VerificationStatusIcon(state: .verified)
    VerificationStatusIcon(state: .error(message: "Failed"))
  }
  .padding()
}
