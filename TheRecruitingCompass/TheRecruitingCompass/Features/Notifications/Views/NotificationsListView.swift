import SwiftUI

struct NotificationsListView: View {
  @ObservedObject var viewModel: NotificationsListViewModel

  @State private var showDeleteAlert = false
  @State private var showClearReadAlert = false
  @State private var pendingDeleteId: String?

  var body: some View {
    NavigationStack {
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

        NotificationSearchBar(
          searchText: $viewModel.searchText,
          onSearchChanged: { _ in }
        )

        NotificationFilterChips(
          selectedType: $viewModel.selectedTypeFilter,
          onFilterChanged: { _ in }
        )

        if viewModel.isLoading && viewModel.notifications.isEmpty {
          ProgressView("Loading notifications...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.filteredNotifications.isEmpty {
          NotificationEmptyState()
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
      .navigationBarTitleDisplayMode(.large)
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
  }
}
