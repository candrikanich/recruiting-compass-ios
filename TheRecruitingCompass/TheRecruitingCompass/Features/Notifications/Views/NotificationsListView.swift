import SwiftUI

struct NotificationsListView: View {
  @StateObject private var viewModel = NotificationsListViewModel()

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
            Task { await viewModel.deleteAllRead() }
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
                    Task { await viewModel.deleteNotification(id: notification.id) }
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
    }
  }
}
