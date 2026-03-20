import SwiftUI

struct ActivityFeedView: View {
  @State private var viewModel = ActivityFeedViewModel()

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.activities.isEmpty {
        LoadingStateView(message: "Loading activities...")
      } else if let error = viewModel.errorMessage, viewModel.activities.isEmpty {
        errorState(error)
      } else if viewModel.activities.isEmpty {
        emptyState
      } else {
        activityListContent
      }
    }
    .navigationTitle("Activity History")
    .refreshable { await viewModel.loadActivities() }
    .task { await viewModel.loadActivities() }
  }

  // MARK: - List Content

  @ViewBuilder
  private var activityListContent: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        filterSection
          .padding(.horizontal, 16)
          .padding(.top, 8)
          .padding(.bottom, 12)

        if viewModel.filteredActivities.isEmpty {
          filteredEmptyState
            .padding(.top, 40)
        } else {
          ForEach(viewModel.paginatedActivities) { event in
            if event.isClickable {
              NavigationLink(value: ActivityDestination(event: event)) {
                ActivityEventItem(event: event)
              }
              .buttonStyle(.plain)
              .padding(.horizontal, 16)
              .padding(.vertical, 4)
            } else {
              ActivityEventItem(event: event)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
          }

          if viewModel.totalPages > 1 {
            paginationControls
              .padding(.horizontal, 16)
              .padding(.vertical, 16)
          }
        }
      }
    }
  }

  // MARK: - Filter Section

  @ViewBuilder
  private var filterSection: some View {
    VStack(spacing: 12) {
      Picker("Activity Type", selection: $viewModel.selectedType) {
        Text("All Activities").tag(nil as ActivityEventType?)
        ForEach(ActivityEventType.allCases, id: \.self) { type in
          Text(type.label).tag(type as ActivityEventType?)
        }
      }
      .pickerStyle(.menu)

      Picker("Date Range", selection: $viewModel.selectedDateRange) {
        ForEach(ActivityDateRange.allCases, id: \.self) { range in
          Text(range.label).tag(range)
        }
      }
      .pickerStyle(.segmented)

      HStack {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(Color.iconGray)
          .accessibilityHidden(true)

        TextField("Search activities...", text: $viewModel.searchQuery)
          .textFieldStyle(.plain)
          .accessibilityIdentifier("activity-feed-search-field")

        if !viewModel.searchQuery.isEmpty {
          Button {
            viewModel.searchQuery = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(Color.iconGray)
          }
          .frame(minWidth: 44, minHeight: 44)
          .accessibilityLabel("Clear search")
          .accessibilityIdentifier("activity-feed-clear-search")
        }
      }
      .padding(10)
      .background(Color(.systemGray6))
      .clipShape(.rect(cornerRadius: 10))
    }
    .padding(16)
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
  }

  // MARK: - Pagination

  @ViewBuilder
  private var paginationControls: some View {
    HStack {
      Button {
        viewModel.previousPage()
      } label: {
        Label("Previous", systemImage: "chevron.left")
          .font(.subheadline)
      }
      .disabled(!viewModel.hasPreviousPage)
      .frame(minWidth: 44, minHeight: 44)
      .accessibilityIdentifier("activity-feed-previous-page")

      Spacer()

      Text("Page \(viewModel.currentPage) of \(viewModel.totalPages)")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Page \(viewModel.currentPage) of \(viewModel.totalPages)")
        .accessibilityIdentifier("activity-feed-page-indicator")

      Spacer()

      Button {
        viewModel.nextPage()
      } label: {
        Label("Next", systemImage: "chevron.right")
          .font(.subheadline)
          .labelStyle(.trailingIcon)
      }
      .disabled(!viewModel.hasNextPage)
      .frame(minWidth: 44, minHeight: 44)
      .accessibilityIdentifier("activity-feed-next-page")
    }
    .padding(12)
    .background(Color(.systemBackground))
    .clipShape(.rect(cornerRadius: 12))
    .accessibilityIdentifier("activity-feed-pagination")
  }

  // MARK: - States

  @ViewBuilder
  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "sparkles")
        .font(.largeTitle)
        .imageScale(.large)
        .foregroundStyle(Color.iconGray)
        .accessibilityHidden(true)

      Text("No activities found")
        .font(.title3)
        .fontWeight(.medium)
        .foregroundStyle(.primary)

      Text("Your recruiting activity will appear here")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(32)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("activity-feed-empty-state")
  }

  @ViewBuilder
  private var filteredEmptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "line.3.horizontal.decrease.circle")
        .font(.largeTitle)
        .foregroundStyle(Color.iconGray)
        .accessibilityHidden(true)

      Text("No activities found")
        .font(.title3)
        .fontWeight(.medium)

      Text("Try adjusting your filters or search query")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Button("Clear Filters") {
        viewModel.clearFilters()
      }
      .buttonStyle(.bordered)
      .frame(minWidth: 44, minHeight: 44)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("activity-feed-filtered-empty-state")
  }

  private func errorState(_ message: String) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .imageScale(.large)
        .foregroundStyle(Color.errorRed)
        .accessibilityHidden(true)

      Text(message)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      Button("Try Again") {
        Task { await viewModel.loadActivities() }
      }
      .buttonStyle(.borderedProminent)
      .frame(minWidth: 44, minHeight: 44)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(32)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("activity-feed-error-state")
  }
}

// MARK: - Label Style

private struct TrailingIconLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 4) {
      configuration.title
      configuration.icon
    }
  }
}

extension LabelStyle where Self == TrailingIconLabelStyle {
  static var trailingIcon: TrailingIconLabelStyle { .init() }
}

#Preview {
  NavigationStack {
    ActivityFeedView()
  }
}
