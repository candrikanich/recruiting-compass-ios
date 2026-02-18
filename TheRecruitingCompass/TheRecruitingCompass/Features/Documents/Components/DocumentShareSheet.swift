import SwiftUI

struct DocumentShareSheet: View {
  @Bindable var viewModel: DocumentDetailViewModel

  private var sharedWithSection: some View {
    Group {
      if let sharedIds = viewModel.document?.sharedWithSchools, !sharedIds.isEmpty {
        Section("Shared With") {
          ForEach(sharedIds, id: \.self) { schoolId in
            HStack {
              Text(viewModel.schoolName(for: schoolId))
              Spacer()
              Button("Remove", role: .destructive) {
                Task { await viewModel.removeShare(schoolId: schoolId) }
              }
              .font(.caption)
              .accessibilityLabel("Remove \(viewModel.schoolName(for: schoolId))")
            }
          }
        }
      }
    }
  }

  private var addSchoolsSection: some View {
    Section("Add Schools") {
      ForEach(availableSchools, id: \.id) { school in
        addSchoolRow(school)
      }
      if viewModel.availableSchoolsForShare.isEmpty {
        Text("No other schools to add")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
      }
    }
  }

  private var availableSchools: [School] {
    viewModel.availableSchoolsForShare
  }

  private func addSchoolRow(_ school: School) -> some View {
    Button {
      viewModel.toggleSchoolSelection(school.id)
    } label: {
      HStack {
        Text(school.name)
        Spacer()
        if viewModel.selectedSchoolIds.contains(school.id) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.accentBlue)
        }
      }
      .frame(minHeight: 44)
      .contentShape(Rectangle())
    }
    .accessibilityLabel(school.name)
    .accessibilityHint(viewModel.selectedSchoolIds.contains(school.id) ? "Selected. Double tap to deselect." : "Double tap to add")
  }

  var body: some View {
    NavigationStack {
      List {
        sharedWithSection
        addSchoolsSection
      }
      .navigationTitle("Share Document")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            viewModel.showShareModal = false
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task { await viewModel.saveShare() }
          }
          .disabled(viewModel.selectedSchoolIds.isEmpty)
          .tint(Color.primaryGreen)
        }
      }
    }
  }
}
