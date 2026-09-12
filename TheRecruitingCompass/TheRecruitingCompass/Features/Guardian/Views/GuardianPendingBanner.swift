import SwiftUI

/// Non-dismissible banner shown on the dashboard while a self-signed-up
/// 13-17 player's guardian hasn't confirmed yet. Mirrors web's
/// `GuardianPendingBanner.vue` — deliberately no way to hide it, since the
/// pending confirmation gates real functionality (coach messaging, profile
/// publishing).
struct GuardianPendingBanner: View {
  @Bindable var viewModel: GuardianStatusViewModel

  var body: some View {
    Group {
      if viewModel.isPending {
        content
      }
    }
    .task { await viewModel.refresh() }
  }

  @ViewBuilder
  private var content: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: "clock.badge.exclamationmark")
          .foregroundStyle(.orange)
          .accessibilityHidden(true)
        Text("Waiting on your guardian")
          .font(.subheadline.weight(.semibold))
      }

      if let masked = viewModel.status?.guardianEmailMasked {
        Text("We emailed \(masked) to confirm your account. Sending messages to coaches and publishing your profile stay locked until they do.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if let resendMessage = viewModel.resendMessage {
        Text(resendMessage)
          .font(.caption.weight(.medium))
          .foregroundStyle(.blue)
      }

      Button(action: { Task { await viewModel.resend() } }) {
        if viewModel.isResending {
          ProgressView().controlSize(.small)
        } else {
          Text("Resend confirmation email")
            .font(.caption.weight(.semibold))
        }
      }
      .disabled(viewModel.isResending)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.orange.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .padding(.horizontal)
    .padding(.top, 8)
  }
}
