import SwiftUI

/// Presented as a `.sheet` when a background token refresh returns a 401.
/// Use instead of `AppErrorView` to avoid replacing the full screen when the
/// user may have unsaved form state.
struct SessionExpiredSheet: View {
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(hex: "F59E0B"))
                    .accessibilityHidden(true)

                Text("You've been away for a while.")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("For your security, we signed you out after a period of inactivity. Log back in to continue.")
                    .font(.body)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onSignIn) {
                Text("Sign In Again")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(.white)
                    .background(LinearGradient.primaryButton)
                    .clipShape(.rect(cornerRadius: 8))
            }
            .accessibilityLabel("Sign in again")
        }
        .padding(32)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            UIAccessibility.post(
                notification: .announcement,
                argument: "You've been away for a while. Please sign in again."
            )
        }
    }
}

#Preview {
    Text("Behind the sheet")
        .sheet(isPresented: .constant(true)) {
            SessionExpiredSheet(onSignIn: {})
        }
}
