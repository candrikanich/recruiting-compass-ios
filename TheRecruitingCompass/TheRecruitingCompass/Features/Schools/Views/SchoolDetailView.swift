import SwiftUI

struct SchoolDetailView: View {
  let schoolId: String

  @StateObject private var viewModel: SchoolDetailViewModel
  @Environment(\.dismiss) private var dismiss

  init(schoolId: String) {
    self.schoolId = schoolId
    _viewModel = StateObject(wrappedValue: SchoolDetailViewModel(schoolId: schoolId))
  }

  var body: some View {
    ScrollView {
      if viewModel.isLoading && viewModel.school == nil {
        LoadingStateView(message: "Loading school...")
          .padding(.top, 100)
      } else if let school = viewModel.school {
        detailContent(school: school)
      } else if let error = viewModel.errorMessage {
        ErrorStateView(message: error)
          .padding(.top, 100)
      }
    }
    .navigationTitle("School Details")
    .navigationBarTitleDisplayMode(.inline)
    .refreshable {
      await viewModel.loadSchool()
    }
    .task {
      await viewModel.loadSchool()
    }
    .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
      Button("OK") { viewModel.errorMessage = nil }
    } message: {
      if let error = viewModel.errorMessage {
        Text(error)
      }
    }
  }

  @ViewBuilder
  private func detailContent(school: School) -> some View {
    VStack(spacing: 0) {
      SchoolDetailHeader(
        school: school,
        onToggleFavorite: {
          Task { await viewModel.toggleFavorite() }
        }
      )

      Divider()

      VStack(spacing: 24) {
        statusPickerSection(school: school)

        SchoolStatusHistorySection(history: viewModel.statusHistory)
          .padding(.horizontal)

        // TODO: Add more sections in Phase 2-4
      }
      .padding(.vertical)
    }
  }

  @ViewBuilder
  private func statusPickerSection(school: School) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Recruiting Status")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      HStack {
        Menu {
          ForEach(SchoolStatus.allCases, id: \.self) { status in
            Button {
              Task { await viewModel.updateStatus(to: status) }
            } label: {
              HStack {
                Text(status.displayName)
                if status.rawValue == school.status {
                  Image(systemName: "checkmark")
                }
              }
            }
          }
        } label: {
          HStack {
            Text((SchoolStatus(rawValue: school.status) ?? .interested).displayName)
              .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.up.chevron.down")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 10)
          .background(Color(.systemGray6))
          .cornerRadius(8)
        }
        .disabled(viewModel.isUpdatingStatus)

        if viewModel.isUpdatingStatus {
          ProgressView()
            .accessibilityLabel("Updating status")
        }
      }
    }
    .padding(.horizontal)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Recruiting status: \((SchoolStatus(rawValue: school.status) ?? .interested).displayName)")
    .accessibilityHint("Double tap to change status")
  }
}

#Preview {
  NavigationStack {
    SchoolDetailView(schoolId: "preview-school-1")
  }
}
