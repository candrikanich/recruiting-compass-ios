import Foundation

/// The purchase SDK as the paywall needs it. The app uses `RevenueCatPurchases`; tests use a fake.
protocol PurchasesProviding: Sendable {
  /// False when no SDK key was built in: there is nothing to sell, so every purchase surface stays hidden.
  /// Says nothing about whether the SDK has started: it only starts once a parent logs in.
  var hasAPIKey: Bool { get }
  /// Attaches the SDK's customer to the signed-in user, starting the SDK as that user if it has not started yet.
  /// Must finish before any purchase or restore.
  func logIn(appUserId: String) async throws
  /// Detaches the customer. Does nothing, and never starts the SDK, when it has not started.
  func logOut() async throws
  func availablePackages() async throws -> [PaywallPackage]
  /// The product the customer's `full_access` entitlement currently comes from, if any.
  func currentProductId() async throws -> String?
  func purchase(packageId: String) async throws -> PurchaseOutcome
  func restorePurchases() async throws
  func presentManageSubscriptions() async throws
}

enum PurchasesError: Error, Equatable {
  case notConfigured
  case unknownPackage
}
