import SwiftUI

struct BiometricLockView: View {
  let authManager: AuthManager
  let onSuccess: () -> Void
  let onFailure: () -> Void

  @ScaledMetric private var iconSize: CGFloat = 56

  var body: some View {
    ZStack {
      LinearGradient.landingBackground
        .ignoresSafeArea()

      VStack(spacing: 32) {
        Image("AppLogo")
          .resizable()
          .scaledToFit()
          .frame(width: 160)
          .accessibilityHidden(true)

        VStack(spacing: 16) {
          Image(systemName: "faceid")
            .font(.system(size: iconSize))
            .foregroundStyle(.white)
            .accessibilityHidden(true)

          Text("Sign in with Face ID")
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
        }

        VStack(spacing: 12) {
          Button(action: { Task { await authenticate() } }) {
            Text("Use Face ID")
              .font(.callout.weight(.semibold))
              .frame(maxWidth: .infinity)
              .frame(minHeight: 48)
              .foregroundStyle(.white)
              .background(Color.white.opacity(0.25))
              .clipShape(.rect(cornerRadius: 8))
          }
          .accessibilityLabel(String(localized: "Sign in with Face ID"))

          Button(action: onFailure) {
            Text("Use Password Instead")
              .font(.footnote)
              .foregroundStyle(.white.opacity(0.8))
              .frame(minHeight: 44)
          }
          .accessibilityLabel(String(localized: "Sign in with password"))
          .accessibilityHint("Returns to the login form")
        }
        .padding(.horizontal, 40)
      }
    }
    .task { await authenticate() }
  }

  private func authenticate() async {
    do {
      try await authManager.authenticateWithBiometrics()
      onSuccess()
    } catch BiometricError.cancelled {
      // User cancelled — stay on lock screen so they can retry
    } catch {
      onFailure()
    }
  }
}
