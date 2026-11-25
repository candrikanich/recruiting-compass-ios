import Foundation

/// One purchasable package from the RevenueCat offering. `priceText` is the StoreKit-localized price string:
/// no price is ever written into the app.
struct PaywallPackage: Identifiable, Equatable, Sendable {
  let id: String
  let product: SubscriptionProduct
  let priceText: String
}

enum PurchaseOutcome: Equatable, Sendable {
  case purchased
  case cancelled
}
