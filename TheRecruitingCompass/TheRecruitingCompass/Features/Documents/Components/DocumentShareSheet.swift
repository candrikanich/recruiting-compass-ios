import SwiftUI

struct DocumentShareSheet: View {
  @Bindable var viewModel: DocumentDetailViewModel

  var body: some View {
    NavigationStack {
      List {
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
        Section("Add Schools") {
          ForEach(viewModel.availableSchoolsForShare, id: \.id) { school in
            Button {
              viewModel.toggleSchoolSelection(school.id)
            } label: {
              HStack {
                Text(school.name)
                Spacer()
                if viewModel.selectedSchoolIds.contains(school.id) {
                  Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.accentBlue)
                }
              }
            }
          }
          if viewModel.availableSchoolsForShare.isEmpty {
            Text("No other schools to add")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
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
