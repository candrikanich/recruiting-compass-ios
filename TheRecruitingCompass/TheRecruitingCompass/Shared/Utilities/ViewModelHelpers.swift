import Foundation
import OSLog

/// Shared helpers for ViewModels (loading flags, error handling). Use from @MainActor ViewModels.
enum ViewModelHelpers {

  /// Sets the loading flag to true for the duration of `operation`, then false. Use for isLoading, isSaving, isDeleting, etc.
  /// Pass a setter to avoid passing actor-isolated `inout` across async boundaries (e.g. `set: { self.isUpdating = $0 }`).
  @MainActor
  static func withLoading<T>(set: @escaping (Bool) -> Void, operation: () async throws -> T) async rethrows -> T {
    set(true)
    defer { set(false) }
    return try await operation()
  }

  /// Logs the error and calls `setMessage` with a user-facing message. Use to set errorMessage or activeAlert.
  @MainActor
  static func handleError(
    _ error: Error,
    userMessage: String,
    file: String = #file,
    function: String = #function,
    logger: Logger? = nil,
    setMessage: (String) -> Void
  ) {
    setMessage(userMessage)
    let fileName = (file as NSString).lastPathComponent
    if let logger {
      logger.error("[\(fileName):\(function)] \(error.localizedDescription)")
    }
  }
}
