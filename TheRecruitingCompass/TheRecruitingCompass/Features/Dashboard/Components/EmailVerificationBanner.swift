import SwiftUI

/// Dismissible banner shown on the dashboard while the account's email isn't
/// verified yet. Mirrors web's `EmailVerificationBanner.vue` — non-blocking
/// (verification is a background step, not a login gate; see PR #167/#826),
/// unlike `GuardianPendingBanner` which deliberately can't be dismissed.
struct EmailVerificationBanner: View {
  @Bindable var viewModel: EmailVerificationBannerViewModel

  /// In-memory only — resets on app relaunch, mirroring web's sessionStorage
  /// dismiss (comes back next session, not next screen visit).
  @State private var isDismissed = false

  var body: some View {
    Group {
      if !isDismissed && !viewModel.isVerified {
        content
      }
    }
    .task { await viewModel.refresh() }
  }

  @ViewBuilder
  private var content: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: "envelope.badge")
          .foregroundStyle(.orange)
          .accessibilityHidden(true)
        Text("Please verify your email address")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Button(action: { isDismissed = true }) {
          Image(systemName: "xmark")
            .foregroundStyle(.secondary)
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("Dismiss")
      }

      Text("Check your inbox for a verification link — some features may be limited until it's confirmed.")
        .font(.caption)
        .foregroundStyle(.secondary)

      if let resendMessage = viewModel.resendMessage {
        Text(resendMessage)
          .font(.caption.weight(.medium))
          .foregroundStyle(viewModel.resendFailed ? .red : .blue)
      }

      Button(action: { Task { await viewModel.resend() } }) {
        if viewModel.isResending {
          ProgressView().controlSize(.small)
        } else {
          Text("Resend email")
            .font(.caption.weight(.semibold))
        }
      }
      .frame(minWidth: 44, minHeight: 44)
      .contentShape(Rectangle())
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
