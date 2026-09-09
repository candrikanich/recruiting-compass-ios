import SwiftUI
import WebKit

/// Hosts the shared, hidden WKWebView that runs the Cloudflare Turnstile challenge.
/// Mount exactly once (see `TheRecruitingCompassApp`) so the web view stays attached
/// to a live window — Turnstile's bot-detection heuristics require that; a WKWebView
/// never added to any window's hierarchy can be flagged as headless/suspicious.
struct TurnstileWidgetView: UIViewRepresentable {
  func makeUIView(context: Context) -> WKWebView {
    TurnstileTokenProvider.shared.webView
  }

  func updateUIView(_ uiView: WKWebView, context: Context) {}
}
