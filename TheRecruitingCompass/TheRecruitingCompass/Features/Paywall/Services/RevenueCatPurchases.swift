import Foundation
import OSLog
import RevenueCat
import StoreKit
import UIKit

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "Purchases")

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

  /// Call once at launch. The customer stays anonymous until `BillingSession` logs in the signed-in user.
  static func configure() {
    guard let key = apiKey() else {
      logger.info("REVENUECAT_API_KEY not configured — purchases disabled")
      return
    }
    #if DEBUG
    Purchases.logLevel = .debug
    #endif
    Purchases.configure(withAPIKey: key)
  }
}

actor RevenueCatPurchases: PurchasesProviding {
  private var packagesById: [String: Package] = [:]
  /// Whether `RevenueCatConfig.configure()` found a key and set the SDK up. Injectable so a test can cover both
  /// answers without a real key; the app always uses the SDK's own answer.
  private let sdkIsConfigured: @Sendable () -> Bool

  init(sdkIsConfigured: @escaping @Sendable () -> Bool = { Purchases.isConfigured }) {
    self.sdkIsConfigured = sdkIsConfigured
  }

  nonisolated var isConfigured: Bool { sdkIsConfigured() }

  private func purchases() throws -> Purchases {
    guard sdkIsConfigured() else { throw PurchasesError.notConfigured }
    return Purchases.shared
  }

  func logIn(appUserId: String) async throws {
    _ = try await purchases().logIn(appUserId)
  }

  func logOut() async throws {
    let purchases = try purchases()
    // Signing out of an anonymous customer is an SDK error, and there is nothing to detach.
    guard !purchases.isAnonymous else { return }
    _ = try await purchases.logOut()
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
