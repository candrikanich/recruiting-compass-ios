import SwiftUI

/// Reports `onboarding_v2_started` on appear and again when the user's role resolves, since the event is
/// skipped while the role is unknown. OnboardingAnalytics dedupes per user, so it still fires once.
struct OnboardingStartedTracking: ViewModifier {
  let user: User?

  func body(content: Content) -> some View {
    content.onChange(of: user?.role, initial: true) {
      OnboardingAnalytics.onboardingStarted(user: user)
    }
  }
}
