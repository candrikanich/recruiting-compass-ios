import Foundation
@testable import TheRecruitingCompass

final class MockNotificationsService: NotificationsManaging {
  var shouldSucceed = true
  var mockNotifications: [AppNotification] = []
  var markAsReadCallCount = 0
  var markAllAsReadCallCount = 0
  var deleteCallCount = 0
  var deleteAllReadCallCount = 0
  var lastMarkedReadId: String?
  var lastDeletedId: String?

  func fetchNotifications(userId: String) async throws -> [AppNotification] {
    if !shouldSucceed { throw NotificationServiceError.networkTimeout }
    return mockNotifications
  }

  func markAsRead(id: String) async throws -> AppNotification {
    markAsReadCallCount += 1
    lastMarkedReadId = id
    if !shouldSucceed { throw NotificationServiceError.invalidResponse }

    guard let index = mockNotifications.firstIndex(where: { $0.id == id }) else {
      throw NotificationServiceError.invalidResponse
    }

    let updated = mockNotifications[index].markingAsRead()
    mockNotifications[index] = updated
    return updated
  }

  func markAllAsRead(userId: String) async throws {
    markAllAsReadCallCount += 1
    if !shouldSucceed { throw NotificationServiceError.networkTimeout }
  }

  func deleteNotification(id: String) async throws {
    deleteCallCount += 1
    lastDeletedId = id
    if !shouldSucceed { throw NotificationServiceError.networkTimeout }
    mockNotifications.removeAll { $0.id == id }
  }

  func deleteAllRead(userId: String) async throws {
    deleteAllReadCallCount += 1
    if !shouldSucceed { throw NotificationServiceError.networkTimeout }
    mockNotifications.removeAll { $0.isRead }
  }

  func reset() {
    shouldSucceed = true
    mockNotifications = []
    markAsReadCallCount = 0
    markAllAsReadCallCount = 0
    deleteCallCount = 0
    deleteAllReadCallCount = 0
    lastMarkedReadId = nil
    lastDeletedId = nil
  }
}
