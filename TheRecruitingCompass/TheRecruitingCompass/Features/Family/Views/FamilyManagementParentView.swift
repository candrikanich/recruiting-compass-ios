import SwiftUI

struct FamilyManagementParentView: View {
  @ObservedObject var viewModel: FamilyManagementViewModel

  var body: some View {
    ScrollView {
      VStack(spacing: FamilyConstants.Spacing.large) {
        joinFamilyCard
        myFamiliesSection
      }
      .padding(.horizontal, FamilyConstants.Spacing.medium)
      .padding(.top, FamilyConstants.Spacing.medium)
    }
  }

  // MARK: - Join Family Card
  private var joinFamilyCard: some View {
    VStack(spacing: FamilyConstants.Spacing.medium) {
      Text("Join a Family")
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)

      Text("Enter a family code shared by a player")
        .font(.subheadline)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)

      VStack(spacing: FamilyConstants.Spacing.small) {
        TextField("FAM-XXXXXX", text: $viewModel.codeInput)
          .textFieldStyle(.roundedBorder)
          .textInputAutocapitalization(.characters)
          .autocorrectionDisabled(true)
          .font(.system(.body, design: .monospaced))
          .onChange(of: viewModel.codeInput) { _ in
            viewModel.formatCodeInput()
          }
          .accessibilityLabel("Enter family code")
          .accessibilityHint("Enter a code like FAM-XXXXXX")

        Button(action: { Task { await viewModel.joinFamily() } }) {
          if viewModel.isLoading {
            ProgressView()
              .progressViewStyle(.circular)
              .tint(.white)
          } else {
            Text("Join Family")
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FamilyConstants.Spacing.small)
        .background(viewModel.isCodeInputValid && !viewModel.isLoading ? Color.blue : Color.gray)
        .foregroundColor(.white)
        .cornerRadius(8)
        .disabled(!viewModel.isCodeInputValid || viewModel.isLoading)
        .accessibilityLabel("Join family button")
        .accessibilityHint(viewModel.isCodeInputValid ? "Join the family using the entered code" : "Enter a valid family code to enable")
      }
    }
    .padding(FamilyConstants.Spacing.medium)
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
  }

  // MARK: - My Families Section
  private var myFamiliesSection: some View {
    VStack(spacing: FamilyConstants.Spacing.medium) {
      HStack {
        Text("My Families")
          .font(.headline)
        Spacer()
        Text("\(viewModel.parentFamilies.count)")
          .font(.subheadline)
          .foregroundColor(.secondary)
      }

      if viewModel.isLoading && viewModel.parentFamilies.isEmpty {
        ProgressView()
          .accessibilityLabel("Loading families")
          .frame(maxWidth: .infinity)
          .padding(.vertical, FamilyConstants.Spacing.extraLarge)
      } else if viewModel.parentFamilies.isEmpty {
        emptyFamiliesState
      } else {
        familiesList
      }
    }
    .padding(FamilyConstants.Spacing.medium)
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
  }

  private var emptyFamiliesState: some View {
    VStack(spacing: FamilyConstants.Spacing.small) {
      Image(systemName: "person.2.slash")
        .font(.largeTitle)
        .foregroundColor(.secondary)
        .accessibilityHidden(true)
      Text("No families joined yet")
        .font(.headline)
      Text("Ask a player to share their family code")
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(.vertical, FamilyConstants.Spacing.extraLarge)
    .frame(maxWidth: .infinity)
  }

  private var familiesList: some View {
    VStack(spacing: FamilyConstants.Spacing.small) {
      ForEach(viewModel.parentFamilies) { family in
        ParentFamilyCard(family: family)
      }
    }
  }
}
