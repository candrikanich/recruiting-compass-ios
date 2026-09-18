import SwiftUI
import UIKit

/// Standalone invite-your-athlete sheet, opened from the dashboard's ParentOnboardingBanner.
/// Matches web: inviting the athlete is never a blocking onboarding step, only a dashboard nudge.
struct InviteAthleteView: View {
  @Bindable var viewModel: ParentOnboardingWizardViewModel
  var onDismiss: (() -> Void)?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: FamilyConstants.Spacing.medium) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Invite your player")
              .font(.headline)
            Text("Send them an email invite or share your family code.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          VStack(alignment: .leading, spacing: FamilyConstants.Spacing.small) {
            Text("Player's email address")
              .font(.subheadline.weight(.medium))
            TextField("player@example.com", text: $viewModel.inviteEmail)
              .keyboardType(.emailAddress)
              .textContentType(.emailAddress)
              .autocapitalization(.none)
              .accessibilityLabel(String(localized: "Player email for invite"))
              .formFieldStyle()
          }

          if let error = viewModel.errorMessage {
            Text(error)
              .font(.caption)
              .foregroundStyle(.red)
          }

          Button {
            Task { await viewModel.sendInvite() }
          } label: {
            if viewModel.isLoading {
              ProgressView().tint(.white)
            } else {
              Text("Send Invite")
                .font(.callout.weight(.semibold))
            }
          }
          .frame(maxWidth: .infinity)
          .frame(minHeight: 48)
          .foregroundStyle(.white)
          .background(LinearGradient.primaryButton)
          .clipShape(.rect(cornerRadius: 8))
          .opacity(!viewModel.isInviteStepValid || viewModel.isLoading ? 0.5 : 1)
          .disabled(!viewModel.isInviteStepValid || viewModel.isLoading)
          .accessibilityLabel(String(localized: "Send invite"))

          Text("Or share your family code")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.top, FamilyConstants.Spacing.small)

          if viewModel.isLoadingFamilyCode {
            HStack(spacing: FamilyConstants.Spacing.small) {
              ProgressView()
              Text("Loading family code…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(FamilyConstants.Spacing.small)
            .background(Color(.tertiarySystemFill))
            .clipShape(.rect(cornerRadius: 8))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "Loading family code"))
          } else if let code = viewModel.familyCode {
            VStack(spacing: FamilyConstants.Spacing.small) {
              Text(code)
                .font(.system(.title2, design: .monospaced).weight(.bold))
                .tracking(2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FamilyConstants.Spacing.medium)
                .background(Color.gray.opacity(0.1))
                .clipShape(.rect(cornerRadius: 12))
                .accessibilityLabel(String(localized: "\(FamilyUtilities.formatCodeForVoiceOver(code))"))
              Button {
                UIPasteboard.general.string = code
              } label: {
                Label("Copy", systemImage: "doc.on.doc")
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.bordered)
              .accessibilityLabel(String(localized: "Copy family code"))
              Text("Your player enters this code during their signup.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          } else {
            VStack(alignment: .leading, spacing: FamilyConstants.Spacing.small) {
              Text("Family code couldn't be loaded.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
              Button("Retry") {
                Task { await viewModel.loadFamilyCode() }
              }
              .buttonStyle(.bordered)
              .accessibilityLabel(String(localized: "Retry loading family code"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FamilyConstants.Spacing.small)
            .background(Color(.tertiarySystemFill))
            .clipShape(.rect(cornerRadius: 8))
          }
        }
        .padding(FamilyConstants.Spacing.medium)
      }
      .navigationTitle("Invite Player")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            onDismiss?()
          }
        }
      }
      .toast(
        isShowing: Binding(
          get: { viewModel.showSuccessToast },
          set: { viewModel.showSuccessToast = $0 }
        ),
        message: Binding(
          get: { viewModel.successMessage },
          set: { viewModel.successMessage = $0 }
        ),
        type: .success,
        duration: 2.0
      )
      .onChange(of: viewModel.didComplete) { _, completed in
        if completed {
          onDismiss?()
        }
      }
      .task {
        if viewModel.familyCode == nil {
          await viewModel.loadFamilyCode()
        }
      }
    }
  }
}

/// Matches LoginFormField's input styling so the invite sheet reads as part of the signup family.
private extension View {
  func formFieldStyle() -> some View {
    padding(12)
      .background(Color(uiColor: .secondarySystemBackground))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color(uiColor: .separator), lineWidth: 1)
      )
      .clipShape(.rect(cornerRadius: 8))
  }
}
