import Foundation

/// Terms of Service section 22, ported from the web `pages/legal/terms.vue`. Subscriptions are billed through Apple
/// only; `TermsOfServiceContentTests` guards against the website-billing wording returning.
enum TermsOfServiceContent {
  static let subscriptionsHeading = "22. Subscriptions and Payments"

  static let subscriptionClauses = [
    "(a) Free access. The Service is currently offered at no charge. Families who create an account before we begin charging " +
        "(\"Founding Families\") keep full access at no charge for as long as their family account remains active.",
    "(b) Paid plans. We may introduce paid subscription plans. Where offered, a subscription is billed per family account, covers " +
        "every member of that family, and renews automatically at the end of each billing period until cancelled. The price and " +
        "billing period are shown before you subscribe.",
    "(c) Billing and cancellation. Subscriptions are purchased through the Apple App Store and are billed and managed by " +
        "Apple; cancel through your Apple ID subscription settings. Cancellation takes effect at the end of the current " +
        "billing period.",
    "(d) Refunds. Refunds for App Store purchases are governed by Apple's policies.",
    "(e) Free trials and read-only access. We may offer a free trial. When a trial or subscription ends, your family account " +
        "becomes read-only: you can view and export your data but cannot add or change it, and your public athlete profile is not " +
        "available until a subscription is active.",
    "(f) Price changes. We will give existing subscribers at least 30 days' notice before a price change takes effect.",
    "(g) Your data. We do not delete your data when a subscription lapses. Section 14 continues to apply."
  ]
}
