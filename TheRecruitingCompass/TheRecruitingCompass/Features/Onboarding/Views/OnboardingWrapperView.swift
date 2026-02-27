import SwiftUI

/// Wraps OnboardingView and wires onComplete to parent callback.
struct OnboardingWrapperView: View {
  var onComplete: () -> Void
  @State private var viewModel = OnboardingViewModel()

  var body: some View {
    OnboardingView(viewModel: viewModel, onComplete: onComplete)
  }
}
