import SwiftUI

/// Root-level host for the shared Turnstile web view. Normally a hidden 1×1 view (it must stay in a
/// live window for Turnstile's checks); when Cloudflare asks for a checkbox tap it becomes a card
/// the user can solve or cancel. The web view stays in one structural slot so it is never remounted
/// mid-challenge.
struct TurnstileChallengeOverlay: View {
  @ObservedObject var provider: TurnstileTokenProvider = .shared

  private static let widgetSize = CGSize(width: 300, height: 65)

  var body: some View {
    let isVisible = provider.isChallengeVisible
    ZStack {
      if isVisible {
        Color.black.opacity(0.4)
          .ignoresSafeArea()
          .accessibilityHidden(true)
      }
      VStack(spacing: 16) {
        if isVisible {
          VStack(spacing: 6) {
            Text("Quick security check")
              .font(.brand(.headline, weight: .semibold))
            Text("Tap the checkbox to confirm you're human.")
              .font(.brand(.subheadline))
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
        }
        TurnstileWidgetView()
          .frame(
            width: isVisible ? Self.widgetSize.width : 1,
            height: isVisible ? Self.widgetSize.height : 1
          )
          .accessibilityHidden(!isVisible)
        if isVisible {
          Button("Cancel", role: .cancel) { provider.cancelChallenge() }
            .font(.brand(.body, weight: .semibold))
        }
      }
      .padding(isVisible ? 24 : 0)
      .background {
        if isVisible {
          RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground))
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityAddTraits(isVisible ? .isModal : [])
    }
    .allowsHitTesting(isVisible)
    .animation(.easeInOut(duration: 0.2), value: isVisible)
  }
}
