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
    .accessibilityLabel(title)
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

  private var listContent: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        if let error = viewModel.errorMessage {
          errorBanner(message: error)
        }

        filterRow

        if viewModel.isLoading, viewModel.templates.isEmpty {
          loadingPlaceholders
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

  private var filterRow: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        filterPill(label: "All", count: viewModel.typeCounts[nil] ?? 0, type: nil, identifier: "typeFilter.all")
        ForEach(TemplateType.allCases, id: \.self) { type in
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
    .accessibilityLabel("Filter by \(label), \(count) templates")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityIdentifier(identifier)
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "doc.text")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text("No templates yet")
        .font(.headline)
        .foregroundStyle(.primary)

      Text("Create your first template to get started.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      Button {
        viewModel.switchToCreateTab()
      } label: {
        Text("Create Template")
          .font(.body.weight(.medium))
          .foregroundStyle(.white)
          .padding(.horizontal, 24)
          .padding(.vertical, 12)
          .background(Color.accentBlue)
          .clipShape(RoundedRectangle(cornerRadius: 10))
      }
      .padding(.top, 4)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("No templates yet. Create your first template to get started.")
  }

  private var loadingPlaceholders: some View {
    VStack(spacing: 12) {
      ForEach(0..<3, id: \.self) { _ in
        RoundedRectangle(cornerRadius: 12)
          .fill(Color(.tertiarySystemFill))
          .frame(height: 100)
      }
    }
    .padding(.horizontal)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Loading templates")
  }

  private func errorBanner(message: String) -> some View {
    VStack(spacing: 8) {
      Text(message)
        .font(.subheadline)
        .foregroundStyle(.primary)
        .multilineTextAlignment(.center)

      Button("Retry") {
        Task { await viewModel.loadTemplates() }
      }
      .buttonStyle(.borderedProminent)
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(Color.errorRed.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .padding(.horizontal)
  }
}

#Preview {
  NavigationStack {
    CommunicationTemplatesView()
  }
}
