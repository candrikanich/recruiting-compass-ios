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
    }
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
        }
      }
    }
  }
}
