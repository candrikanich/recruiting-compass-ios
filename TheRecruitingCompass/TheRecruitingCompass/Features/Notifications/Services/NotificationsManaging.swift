import Foundation

protocol NotificationsManaging: Sendable {
  func fetchNotifications(userId: String) async throws -> [AppNotification]
  func markAsRead(id: String) async throws -> AppNotification
  func markAllAsRead(userId: String) async throws
  func deleteNotification(id: String) async throws
  func deleteAllRead(userId: String) async throws
}

enum NotificationServiceError: LocalizedError {
  case notAuthenticated
  case networkTimeout
  case serverError(Int)
  case invalidResponse

  var errorDescription: String? {
    switch self {
    case .notAuthenticated:
      return "Session expired. Please log in again."
    case .networkTimeout:
      return "Network timeout. Pull to refresh to try again."
    case .serverError(let code):
      return "Server error (\(code)). Please try again later."
    case .invalidResponse:
      return "Invalid response from server."
    }
  }
}
