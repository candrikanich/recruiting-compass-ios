import SwiftUI

/// Shown right after a player accepts a family invite via signup, so they can confirm (or
/// correct) the birthday their parent entered during onboarding before landing on the dashboard.
struct InviteJoinBirthdayConfirmView: View {
  @Bindable var viewModel: InviteJoinViewModel

  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 8) {
            Image(systemName: "calendar")
              .foregroundStyle(Color.darkSlate)
              .accessibilityHidden(true)
            Text("Confirm Your Birthday")
              .font(.headline)
              .foregroundStyle(Color.darkSlate)
          }

          Text(
            viewModel.dateOfBirthWasPrefilled
              ? "Your parent entered this birthday — please confirm it's correct."
              : "Please confirm your birthday."
          )
          .font(.subheadline)
          .foregroundStyle(Color.secondary)

          DatePicker(
            "Date of Birth",
            selection: $viewModel.confirmedDateOfBirth,
            in: ...Date.now,
            displayedComponents: .date
          )
          .datePickerStyle(.wheel)
          .labelsHidden()

          if let error = viewModel.birthdayConfirmError {
            Text(error)
              .font(.caption)
              .foregroundStyle(.red)
          }
        }

        AsyncButton(
          title: String(localized: "Confirm"),
          loadingTitle: String(localized: "Please wait..."),
          isLoading: viewModel.isConfirmingBirthday
        ) {
          Task { await viewModel.confirmBirthday() }
        }
      }
      .padding(24)
      .background(Color.white.opacity(0.95))
      .clipShape(.rect(cornerRadius: 16))
      .colorScheme(.light)
      .padding(.horizontal, 24)
      .interactiveDismissDisabled()
    }
  }
}
