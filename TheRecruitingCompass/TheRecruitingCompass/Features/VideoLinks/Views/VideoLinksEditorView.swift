import SwiftUI

struct VideoLinksEditorView: View {
  @State private var viewModel: VideoLinksEditorViewModel
  @State private var isShowingAddSheet = false
  @State private var editingLink: VideoLink?

  var showsAddButton: Bool { !viewModel.isReadOnly }

  init(
    athleteUserId: String,
    familyUnitId: String?,
    isReadOnly: Bool,
    service: any VideoLinksManaging = VideoLinksServiceImpl()
  ) {
    _viewModel = State(initialValue: VideoLinksEditorViewModel(
      service: service, athleteUserId: athleteUserId,
      familyUnitId: familyUnitId, isReadOnly: isReadOnly
    ))
  }

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.links.isEmpty {
        LoadingStateView(message: "Loading video links...")
      } else if viewModel.links.isEmpty {
        emptyState
      } else {
        linksList
      }
    }
    .navigationTitle("Video Links")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if showsAddButton {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            editingLink = nil
            isShowingAddSheet = true
          } label: {
            Image(systemName: "plus")
          }
          .disabled(!viewModel.canAddLink)
          .accessibilityLabel(String(localized: "Add video link"))
        }
      }
    }
    .sheet(isPresented: $isShowingAddSheet) {
      NavigationStack {
        AddEditVideoLinkView(viewModel: viewModel, editingLink: editingLink)
      }
    }
    .alert("Error", isPresented: $viewModel.isShowingErrorAlert) {
    } message: {
      if let error = viewModel.errorMessage {
        Text(error)
      }
    }
    .task {
      await viewModel.load()
    }
  }

  // MARK: - Empty State

  @ViewBuilder
  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "play.rectangle")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text("No video links yet")
        .font(.headline)

      Text("Add links to Hudl, YouTube, or Vimeo highlight film for coaches to watch.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)

      if showsAddButton {
        Button {
          editingLink = nil
          isShowingAddSheet = true
        } label: {
          Text("Add your first video link")
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Links List

  @ViewBuilder
  private var linksList: some View {
    List {
      ForEach(viewModel.links) { link in
        VideoLinkRow(link: link)
          .contentShape(Rectangle())
          .onTapGesture {
            guard !viewModel.isReadOnly else { return }
            editingLink = link
            isShowingAddSheet = true
          }
          .swipeActions(edge: .trailing) {
            if !viewModel.isReadOnly {
              Button(role: .destructive) {
                Task { await viewModel.deleteLink(id: link.id) }
              } label: {
                Label("Delete", systemImage: "trash")
              }
            }
          }
      }
    }
  }
}

// MARK: - Video Link Row

private struct VideoLinkRow: View {
  let link: VideoLink

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(link.title?.isEmpty == false ? link.title! : link.platform.displayName)
          .font(.body)
          .fontWeight(.medium)

        Text(link.url)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer()

      Label(link.healthStatus.displayName, systemImage: healthIcon)
        .font(.caption2.weight(.medium))
        .labelStyle(.iconOnly)
        .foregroundStyle(healthColor)
        .accessibilityHidden(false)
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(link.title ?? link.platform.displayName): \(link.healthStatus.displayName)"))
  }

  private var healthIcon: String {
    switch link.healthStatus {
    case .healthy: return "checkmark.circle.fill"
    case .broken: return "exclamationmark.triangle.fill"
    case .unknown: return "questionmark.circle"
    }
  }

  private var healthColor: Color {
    switch link.healthStatus {
    case .healthy: return .green
    case .broken: return .red
    case .unknown: return .secondary
    }
  }
}
