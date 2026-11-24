import Foundation

/// The purchase SDK as the paywall needs it. The app uses `RevenueCatPurchases`; tests use a fake.
protocol PurchasesProviding: Sendable {
  /// Attaches the SDK's customer to the signed-in user. Must finish before any purchase or restore.
  func logIn(appUserId: String) async throws
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
