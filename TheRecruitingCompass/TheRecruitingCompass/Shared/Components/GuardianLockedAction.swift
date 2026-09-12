import SwiftUI

/// Inline lock shown in place of an outbound action a pending minor can't take yet.
///
/// Never a dead end: every locked surface offers the one action that unlocks it.
/// Parity with web's `components/Guardian/GuardianLockedAction.vue`.
struct GuardianLockedAction: View {
  /// What the player is trying to do, e.g. "message coaches".
  let action: String
  @State private var viewModel: GuardianStatusViewModel
  @State private var didSend = false

  /// `nil` builds the default view model inside the initializer rather than in a default
  /// argument, which would be evaluated in the caller's isolation context instead of the
  /// view's.
  init(action: String, viewModel: GuardianStatusViewModel? = nil) {
    self.action = action
    _viewModel = State(initialValue: viewModel ?? GuardianStatusViewModel())
  }

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "lock.fill")
        .foregroundStyle(Color.amberGold)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(message)
          .font(.caption)
          .foregroundStyle(Color.warningBannerBody)
          .fixedSize(horizontal: false, vertical: true)

        if let errorMessage = viewModel.errorMessage {
          Text(errorMessage)
            .font(.caption2)
            .foregroundStyle(.red)
        }
      }

      Spacer(minLength: 8)

      Button {
        Task { didSend = await viewModel.resend() }
      } label: {
        Text(buttonTitle)
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color.warningBannerBody)
      }
      .disabled(viewModel.isSending || didSend)
      .accessibilityLabel("Remind your parent or guardian to confirm your account")
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.Surface.warningTint)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .accessibilityElement(children: .contain)
  }

  private var message: String {
    var text = "Your parent or guardian needs to confirm your account before you can \(action)."
    if let masked = viewModel.guardianEmailMasked {
      text += " We emailed \(masked)."
    }
    return text
  }

  private var buttonTitle: String {
    if viewModel.isSending { return "Sending…" }
    return didSend ? "Sent" : "Remind them"
  }
}
