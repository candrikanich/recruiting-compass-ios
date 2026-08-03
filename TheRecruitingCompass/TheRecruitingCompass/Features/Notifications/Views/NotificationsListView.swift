import SwiftUI

struct NotificationsListView: View {
  @State private var viewModel: NotificationsListViewModel
  @Environment(FamilyManager.self) private var familyManager

  @State private var showDeleteAlert = false
  @State private var showClearReadAlert = false
  @State private var pendingDeleteId: String?

  init(viewModel: NotificationsListViewModel) {
    self._viewModel = State(initialValue: viewModel)
  }

  var body: some View {
    VStack(spacing: 0) {
        NotificationBulkActions(
          hasUnread: viewModel.hasUnread,
          hasRead: viewModel.hasRead,
          onMarkAllRead: {
            Task { await viewModel.markAllAsRead() }
          },
          onClearRead: {
            showClearReadAlert = true
          }
        )

        NotificationFilterChips(
          selectedType: $viewModel.selectedTypeFilter,
          onFilterChanged: { _ in }
        )

        if let errorMessage = viewModel.errorMessage {
          ErrorBanner(message: errorMessage) { viewModel.errorMessage = nil }
            .padding(.horizontal)
        }

        if viewModel.isLoading && viewModel.notifications.isEmpty {
          LoadingStateView(message: "Loading notifications...")
        } else if viewModel.filteredNotifications.isEmpty {
          ScrollView {
            NotificationEmptyState()
              .frame(maxWidth: .infinity)
          }
          .refreshable {
            await viewModel.refresh()
          }
        } else {
          ScrollView {
            LazyVStack(spacing: 12) {
              ForEach(viewModel.filteredNotifications) { notification in
                NotificationCard(
                  notification: notification,
                  onTap: {
                    Task { await viewModel.handleNotificationTap(notification) }
                  },
                  onMarkRead: {
                    Task { await viewModel.markAsRead(id: notification.id) }
                  },
                  onDelete: {
                    pendingDeleteId = notification.id
                    showDeleteAlert = true
                  }
                )
              }
            }
            .padding()
          }
          .refreshable {
            await viewModel.refresh()
          }
        }
      }
      .navigationTitle("Notifications")
      .navigationBarTitleDisplayMode(.inline)
      .searchable(text: $viewModel.searchText, prompt: "Search notifications")
      .navigationDestination(item: $viewModel.selectedDestination) { destination in
        destinationView(for: destination)
      }
      .task {
        await viewModel.fetchNotifications()
      }
      .alert("Delete Notification", isPresented: $showDeleteAlert) {
        Button("Cancel", role: .cancel) {
          pendingDeleteId = nil
        }
        Button("Delete", role: .destructive) {
          if let id = pendingDeleteId {
            Task { await viewModel.deleteNotification(id: id) }
            pendingDeleteId = nil
          }
        }
      } message: {
        Text("Are you sure you want to delete this notification?")
      }
      .alert("Clear Read Notifications", isPresented: $showClearReadAlert) {
        Button("Cancel", role: .cancel) {}
        Button("Clear", role: .destructive) {
          Task { await viewModel.deleteAllRead() }
        }
      } message: {
        Text("Are you sure you want to remove all read notifications?")
      }
  }

  @ViewBuilder
  private func destinationView(for destination: NotificationDestination) -> some View {
    switch destination {
    case .coachDetail(let id):
      CoachDetailView(coachId: id)

    case .schoolDetail(let id):
      SchoolDetailView(schoolId: id)

    case .interactionDetail(let id):
      if let familyUnitId = familyManager.familyUnitId {
        InteractionDetailView(interactionId: id, familyUnitId: familyUnitId)
      } else {
        Text("Unable to load interaction details")
          .foregroundStyle(.secondary)
      }

    case .offerDetail:
      Text("Offer details coming soon")
        .font(.headline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Offer")

    case .eventDetail:
      Text("Event details coming soon")
        .font(.headline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Event")
    }
  }
}
