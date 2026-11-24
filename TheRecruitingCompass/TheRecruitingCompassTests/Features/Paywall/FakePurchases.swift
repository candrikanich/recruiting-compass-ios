import Foundation
@testable import TheRecruitingCompass

struct FakePurchasesFailure: Error, LocalizedError {
  var errorDescription: String? { "RC-INTERNAL-ERROR-7721" }
}

/// Records every call the paywall makes to the purchase SDK. Single-threaded: tests drive it from the main actor.
final class FakePurchases: PurchasesProviding, @unchecked Sendable {
  var isConfigured = true
  private(set) var logInCalls: [String] = []
  private(set) var logOutCount = 0
  private(set) var availablePackagesCount = 0
  private(set) var purchasedPackageIds: [String] = []
  private(set) var restoreCount = 0

  var logInError: Error?
  var logInGate: (@Sendable (String) async -> Void)?
  var packages: [PaywallPackage] = []
  var packagesError: Error?
  var currentProduct: String?
  var purchaseOutcome = PurchaseOutcome.purchased
  var purchaseError: Error?
  var purchaseGate: (@Sendable () async -> Void)?
  var restoreError: Error?
  /// Applied by `restorePurchases`, so a restore can reveal a product the customer already owned.
  var productAfterRestore: String?

  func logIn(appUserId: String) async throws {
    logInCalls.append(appUserId)
    await logInGate?(appUserId)
    if let logInError { throw logInError }
  }

  func logOut() async throws { logOutCount += 1 }

  func availablePackages() async throws -> [PaywallPackage] {
    availablePackagesCount += 1
    if let packagesError { throw packagesError }
    return packages
  }

  func currentProductId() async throws -> String? { currentProduct }

  func purchase(packageId: String) async throws -> PurchaseOutcome {
    purchasedPackageIds.append(packageId)
    await purchaseGate?()
    if let purchaseError { throw purchaseError }
    return purchaseOutcome
  }

  func restorePurchases() async throws {
    restoreCount += 1
    if let restoreError { throw restoreError }
    if let productAfterRestore { currentProduct = productAfterRestore }
  }

  func presentManageSubscriptions() async throws {}

  static func package(_ productId: String, price: String = "STORE-PRICE") -> PaywallPackage {
    PaywallPackage(id: "pkg-\(productId)", product: SubscriptionProduct(productId: productId)!, priceText: price)
  }

  /// The launch offering (Chris, 2026-11-15): players_1 and players_2, monthly and annual.
  static var launchOffering: [PaywallPackage] {
    ["trc_players_1_annual", "trc_players_1_monthly", "trc_players_2_annual", "trc_players_2_monthly"]
      .map { package($0, price: "STORE-\($0)") }
  }
}
