import Foundation
import RevenueCat
import StoreKit
import UIKit

/// RevenueCat public SDK key, read like `SentryDSN`: a build setting surfaced through Info.plist, with an
/// environment fallback for local runs. Without one the paywall has nothing to sell and stays dormant.
enum RevenueCatConfig {
  static let entitlementId = "full_access"

  static func apiKey(
    infoDictionary: [String: Any]? = Bundle.main.infoDictionary,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> String? {
    let fromInfo = (infoDictionary?["RevenueCatAPIKey"] as? String)?.trimmingCharacters(in: .whitespaces)
    // An unset build setting can survive as the literal "$(REVENUECAT_API_KEY)".
    if let fromInfo, !fromInfo.isEmpty, !fromInfo.hasPrefix("$(") { return fromInfo }
    let fromEnv = environment["REVENUECAT_API_KEY"]?.trimmingCharacters(in: .whitespaces)
    if let fromEnv, !fromEnv.isEmpty { return fromEnv }
    return nil
  }
}

/// The part of the RevenueCat SDK whose lifecycle decides what RevenueCat learns about a device. Starting the SDK
/// contacts RevenueCat (IP, device and OS), so it is only ever started as an identified parent: never at launch,
/// never for an athlete, never with the kill switch on. Injectable so tests can watch that without a real key.
struct PurchasesLifecycle: Sendable {
  var isStarted: @Sendable () -> Bool
  /// Starts the SDK already identified as `appUserId`, so no anonymous id is ever created.
  var start: @Sendable (_ apiKey: String, _ appUserId: String) -> Void
  /// Switches a running SDK to another identified user. RevenueCat only merges from an anonymous customer.
  var logIn: @Sendable (_ appUserId: String) async throws -> Void
  var logOut: @Sendable () async throws -> Void

  static let live = PurchasesLifecycle(
    isStarted: { Purchases.isConfigured },
    start: { apiKey, appUserId in
      #if DEBUG
      Purchases.logLevel = .debug
      #endif
      Purchases.configure(withAPIKey: apiKey, appUserID: appUserId)
    },
    logIn: { appUserId in _ = try await Purchases.shared.logIn(appUserId) },
    logOut: {
      // Signing out of an anonymous customer is an SDK error, and there is nothing to detach.
      guard !Purchases.shared.isAnonymous else { return }
      _ = try await Purchases.shared.logOut()
    }
  )
}

actor RevenueCatPurchases: PurchasesProviding {
  private var packagesById: [String: Package] = [:]
  private let apiKey: @Sendable () -> String?
  private let lifecycle: PurchasesLifecycle

  init(
    apiKey: @escaping @Sendable () -> String? = { RevenueCatConfig.apiKey() },
    lifecycle: PurchasesLifecycle = .live
  ) {
    self.apiKey = apiKey
    self.lifecycle = lifecycle
  }

  nonisolated var hasAPIKey: Bool { apiKey() != nil }

  private func purchases() throws -> Purchases {
    guard lifecycle.isStarted() else { throw PurchasesError.notConfigured }
    return Purchases.shared
  }

  /// The first login starts the SDK as this user; later ones switch the running SDK to the new user.
  func logIn(appUserId: String) async throws {
    guard lifecycle.isStarted() else {
      guard let apiKey = apiKey() else { throw PurchasesError.notConfigured }
      lifecycle.start(apiKey, appUserId)
      return
    }
    try await lifecycle.logIn(appUserId)
  }

  /// A SDK that never started has no customer to detach, and starting it just to sign out would create one.
  func logOut() async throws {
    guard lifecycle.isStarted() else { return }
    try await lifecycle.logOut()
  }

  func availablePackages() async throws -> [PaywallPackage] {
    let offering = try await purchases().offerings().current
    let available = offering?.availablePackages ?? []
    var byId: [String: Package] = [:]
    var result: [PaywallPackage] = []
    for package in available {
      guard let product = SubscriptionProduct(productId: package.storeProduct.productIdentifier) else { continue }
      byId[package.identifier] = package
      result.append(PaywallPackage(id: package.identifier, product: product, priceText: package.localizedPriceString))
    }
    packagesById = byId
    return result
  }

  func currentProductId() async throws -> String? {
    try await purchases().customerInfo().entitlements[RevenueCatConfig.entitlementId]
      .flatMap { $0.isActive ? $0.productIdentifier : nil }
  }

  func purchase(packageId: String) async throws -> PurchaseOutcome {
    guard let package = packagesById[packageId] else { throw PurchasesError.unknownPackage }
    let result = try await purchases().purchase(package: package)
    return result.userCancelled ? .cancelled : .purchased
  }

  func restorePurchases() async throws {
    _ = try await purchases().restorePurchases()
  }

  func presentManageSubscriptions() async throws {
    try await purchases().showManageSubscriptions()
  }
}
