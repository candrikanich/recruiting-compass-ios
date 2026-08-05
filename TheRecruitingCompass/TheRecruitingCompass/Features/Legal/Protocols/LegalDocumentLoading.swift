import Foundation

/// Protocol for ViewModels that load a single legal document (e.g. Privacy Policy, Terms of Service).
/// Provides a common contract and default retry behavior.
protocol LegalDocumentLoading {
  var lastUpdated: String { get }
  var isLoading: Bool { get }
  var errorMessage: String? { get }
  func load() async
  func retry() async
}
