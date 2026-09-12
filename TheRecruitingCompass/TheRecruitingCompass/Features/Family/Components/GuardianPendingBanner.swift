import SwiftUI

/// Dashboard banner shown while a 13-17 player waits on guardian confirmation.
///
/// Not dismissible: it is the only explanation for why parts of the app are disabled.
/// Parity with web's `components/Guardian/GuardianPendingBanner.vue` — same copy, same
/// two actions, native container.
struct GuardianPendingBanner: View {
  @State private var viewModel: GuardianStatusViewModel
  @State private var isEditing = false
  @State private var newEmail = ""

  /// `nil` builds the default view model inside the initializer rather than in a default
  /// argument, which would be evaluated in the caller's isolation context instead of the
  /// view's.
  init(viewModel: GuardianStatusViewModel? = nil) {
    _viewModel = State(initialValue: viewModel ?? GuardianStatusViewModel())
  }

  var body: some View {
    Group {
      if viewModel.isPending {
        VStack(alignment: .leading, spacing: 10) {
          HStack(spacing: 8) {
            Image(systemName: "clock")
              .foregroundStyle(Color.amberGold)
              .accessibilityHidden(true)
            Text("Waiting on your parent or guardian")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(Color.warningBannerTitle)
          }

          Text(bodyText)
            .font(.caption)
            .foregroundStyle(Color.warningBannerBody)
            .fixedSize(horizontal: false, vertical: true)

          if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
              .font(.caption)
              .foregroundStyle(.red)
          }

          if isEditing {
            editForm
          } else {
            actionButtons
          }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Surface.warningTint)
        .overlay(alignment: .leading) {
          Rectangle()
            .fill(Color.Surface.warningAccent)
            .frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
      }
    }
    .task { await viewModel.load() }
  }

  private var bodyText: String {
    let lead = viewModel.guardianEmailMasked.map {
      "We emailed \($0) a link to confirm your account."
    } ?? "We emailed your guardian a confirmation link."
    return lead
      + " You can build your school list and track deadlines now — messaging coaches"
      + " and sharing your profile unlock once they confirm."
  }

  private var actionButtons: some View {
    HStack(spacing: 8) {
      Button {
        Task { await viewModel.resend() }
      } label: {
        Text(viewModel.isSending ? "Sending…" : "Resend email")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(Color.Surface.warningCTA)
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }
      .disabled(viewModel.isSending)
      .accessibilityLabel("Resend confirmation email to your parent or guardian")

      Button {
        isEditing = true
      } label: {
        Text("Use a different email")
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color.warningBannerBody)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color.Surface.warningAccent, lineWidth: 1)
          )
      }
      .accessibilityLabel("Use a different parent or guardian email")
    }
  }

  private var editForm: some View {
    VStack(alignment: .leading, spacing: 8) {
      TextField("parent.email@example.com", text: $newEmail)
        .textFieldStyle(.roundedBorder)
        .textContentType(.emailAddress)
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .accessibilityLabel("New parent or guardian email")

      HStack(spacing: 8) {
        Button {
          Task {
            if await viewModel.resend(guardianEmail: newEmail) {
              isEditing = false
              newEmail = ""
            }
          }
        } label: {
          Text(viewModel.isSending ? "Sending…" : "Send")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.Surface.warningCTA)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(viewModel.isSending || newEmail.isEmpty)

        Button("Cancel") {
          isEditing = false
          newEmail = ""
        }
        .font(.caption)
        .foregroundStyle(Color.warningBannerBody)
      }
    }
  }
}
