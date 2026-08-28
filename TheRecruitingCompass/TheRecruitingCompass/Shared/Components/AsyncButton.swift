import SwiftUI

/// Full-width (by default) action button with a loading state, 44pt hit target,
/// VoiceOver labels that swap while busy, and a press scale that respects Reduce Motion.
///
/// ViewModels keep owning `isLoading` so form fields can disable in sync. Pass
/// `isDisabled` for validation; the button also disables itself while loading.
struct AsyncButton: View {
  enum Style {
    case primary
    case secondary
    case destructive
  }

  let title: String
  var loadingTitle: String?
  var systemImage: String?
  var style: Style = .primary
  var isLoading: Bool = false
  var isDisabled: Bool = false
  var expandsHorizontally: Bool = true
  var accessibilityLabelOverride: String?
  var loadingAccessibilityLabel: String?
  var accessibilityHint: String?
  var loadingAccessibilityHint: String?
  let action: () -> Void

  @Environment(\.sizeCategory) private var sizeCategory

  var displayTitle: String {
    if isLoading, let loadingTitle {
      return loadingTitle
    }
    return title
  }

  var isInteractionDisabled: Bool {
    isLoading || isDisabled
  }

  var accessibilityLabel: String {
    if isLoading {
      return loadingAccessibilityLabel ?? displayTitle
    }
    return accessibilityLabelOverride ?? title
  }

  var accessibilityHintText: String {
    if isLoading {
      return loadingAccessibilityHint ?? String(localized: "Please wait")
    }
    return accessibilityHint ?? ""
  }

  var body: some View {
    Button(role: style == .destructive ? .destructive : nil, action: performAction) {
      label
        .font(.callout.weight(.semibold))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(
          maxWidth: expandsHorizontally ? .infinity : nil,
          minHeight: minHeight
        )
        .padding(.horizontal, expandsHorizontally ? 0 : 16)
        .foregroundStyle(foregroundStyle)
        .background(background)
        .clipShape(.rect(cornerRadius: 8))
    }
    .buttonStyle(PressScaleButtonStyle(isDimmed: isInteractionDisabled))
    .disabled(isInteractionDisabled)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint(accessibilityHintText)
    .accessibilityAddTraits(isLoading ? .updatesFrequently : [])
  }

  private var minHeight: CGFloat {
    sizeCategory.isAccessibilityCategory ? 56 : 48
  }

  @ViewBuilder
  private var label: some View {
    HStack(spacing: 8) {
      if isLoading {
        ProgressView()
          .tint(progressTint)
      } else if let systemImage {
        Image(systemName: systemImage)
          .accessibilityHidden(true)
      }

      Text(displayTitle)
    }
  }

  private var foregroundStyle: Color {
    switch style {
    case .primary:
      return .white
    case .secondary:
      return .primary
    case .destructive:
      return Color.errorRed
    }
  }

  private var progressTint: Color {
    style == .primary ? .white : foregroundStyle
  }

  @ViewBuilder
  private var background: some View {
    switch style {
    case .primary:
      LinearGradient.primaryButton
    case .secondary:
      Color.Brand.slate100
    case .destructive:
      Color.Brand.red100
    }
  }

  private func performAction() {
    guard !isInteractionDisabled else { return }
    action()
  }
}

private struct PressScaleButtonStyle: ButtonStyle {
  var isDimmed: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(isDimmed ? 0.5 : 1)
      .scaleEffect(configuration.isPressed && !reduceMotion && !isDimmed ? 0.96 : 1)
      .animation(
        reduceMotion ? nil : .easeOut(duration: 0.12),
        value: configuration.isPressed
      )
  }
}

#Preview("States") {
  VStack(spacing: 16) {
    AsyncButton(title: "Sign In", loadingTitle: "Signing in...", action: {})
    AsyncButton(title: "Sign In", loadingTitle: "Signing in...", isLoading: true, action: {})
    AsyncButton(title: "Sign In", isDisabled: true, action: {})
    AsyncButton(
      title: "Save draft",
      systemImage: "square.and.arrow.down",
      style: .secondary,
      expandsHorizontally: false,
      action: {}
    )
    AsyncButton(title: "Delete school", style: .destructive, action: {})
  }
  .padding()
}

#Preview("Dynamic Type xxxl") {
  AsyncButton(
    title: "Create account and connect to this family",
    loadingTitle: "Please wait...",
    action: {}
  )
  .padding()
  .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
