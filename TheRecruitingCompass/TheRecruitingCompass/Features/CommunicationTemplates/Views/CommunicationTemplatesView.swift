import SwiftUI

struct CommunicationTemplatesView: View {
  @State private var viewModel = CommunicationTemplatesViewModel()

  var body: some View {
    VStack(spacing: 0) {
      tabBar
      content
    }
    .navigationTitle("Communication Templates")
    .navigationBarTitleDisplayMode(.large)
    .searchable(text: $viewModel.searchQuery, prompt: "Search templates...")
    .task { await viewModel.loadTemplates() }
    .alert("Delete Template", isPresented: $viewModel.showDeleteConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        Task { await viewModel.executeDelete() }
      }
    } message: {
      Text("Are you sure you want to delete this template? This action cannot be undone.")
    }
    .accessibilityIdentifier("communicationTemplatesView")
  }

  @ViewBuilder
  private var tabBar: some View {
    HStack(spacing: 0) {
      tabButton(
        title: "My Templates (\(viewModel.templates.count))",
        tab: .list,
        identifier: "communicationTemplates.myTemplatesTab"
      )
      tabButton(
        title: "Create New",
        tab: .create,
        identifier: "communicationTemplates.createTab"
      )
    }
    .padding(.horizontal)
    .padding(.top, 8)
  }

  private func tabButton(title: String, tab: CommunicationTemplatesViewModel.Tab, identifier: String) -> some View {
    let isActive = viewModel.activeTab == tab
    return Button {
      if tab == .create {
        viewModel.switchToCreateTab()
      } else {
        viewModel.activeTab = tab
      }
    } label: {
      Text(title)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(isActive ? .white : .primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(isActive ? Color.accentBlue : Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .accessibilityLabel(String(localized: "\(title)"))
    .accessibilityAddTraits(isActive ? .isSelected : [])
    .accessibilityIdentifier(identifier)
  }

  @ViewBuilder
  private var content: some View {
    switch viewModel.activeTab {
    case .list:
      listContent
    case .create:
      TemplateEditorView(viewModel: viewModel)
    }
  }

  @ViewBuilder
  private var listContent: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        if let error = viewModel.errorMessage {
          InlineErrorView(message: error, onRetry: { Task { await viewModel.loadTemplates() } })
            .padding(.horizontal)
        }

        filterRow

        if viewModel.isLoading, viewModel.templates.isEmpty {
          LoadingStateView(message: "Loading templates...")
        } else if viewModel.filteredTemplates.isEmpty {
          emptyState
        } else {
          ForEach(viewModel.filteredTemplates) { template in
            TemplateCardView(template: template) {
              viewModel.startEditing(template: template)
            }
            .padding(.horizontal)
          }
        }
      }
      .padding(.vertical, 16)
    }
    .refreshable { await viewModel.loadTemplates() }
    .accessibilityIdentifier("communicationTemplates.list")
  }

  @ViewBuilder
  private var filterRow: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        filterPill(label: "All", count: viewModel.typeCounts[nil] ?? 0, type: nil, identifier: "typeFilter.all")
        ForEach(TemplateType.selectable, id: \.self) { type in
          filterPill(
            label: type.displayName,
            count: viewModel.typeCounts[type] ?? 0,
            type: type,
            identifier: "typeFilter.\(type.rawValue)"
          )
        }
      }
      .padding(.horizontal)
    }
    .scrollIndicators(.hidden)
  }

  private func filterPill(label: String, count: Int, type: TemplateType?, identifier: String) -> some View {
    let isSelected = viewModel.filterType == type
    return Button {
      viewModel.selectFilter(type)
    } label: {
      Text("\(label) (\(count))")
        .font(.caption.weight(.medium))
        .foregroundStyle(isSelected ? .white : .primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentBlue : Color(.tertiarySystemFill))
        .clipShape(Capsule())
    }
    .accessibilityLabel(String(localized: "Filter by \(label), \(count) templates"))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityIdentifier(identifier)
  }

  @ViewBuilder
  private var emptyState: some View {
    if !viewModel.searchQuery.isEmpty {
      ContentUnavailableView.search(text: viewModel.searchQuery)
    } else {
      EmptyStateView(
        icon: "doc.text",
        title: String(localized: "No Templates Yet"),
        message: String(localized: "Create your first template to get started."),
        actionTitle: String(localized: "Create Your First Template"),
        actionHint: String(localized: "Opens the form to create a template")
      ) {
        viewModel.switchToCreateTab()
      }
      .frame(maxHeight: .infinity)
    }
  }
}

#Preview {
  NavigationStack {
    CommunicationTemplatesView()
  }
}
