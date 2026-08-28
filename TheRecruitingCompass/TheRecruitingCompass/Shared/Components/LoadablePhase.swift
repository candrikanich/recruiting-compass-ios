import Foundation

/// Screen content phase for list/detail first-load. Refresh with existing data
/// stays `.populated` so pull-to-refresh owns the spinner, not a full-screen replace.
enum LoadablePhase: Equatable {
  case loading
  case empty
  case failed(String)
  case populated

  static func resolve(
    isLoading: Bool,
    isEmpty: Bool,
    errorMessage: String? = nil
  ) -> LoadablePhase {
    if isLoading && isEmpty {
      return .loading
    }

    if isEmpty, let errorMessage, !errorMessage.isEmpty {
      return .failed(errorMessage)
    }

    if isEmpty {
      return .empty
    }

    return .populated
  }
}
