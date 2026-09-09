import Foundation
import WebKit
import Observation

/// Owns the single WKWebView that runs an invisible Cloudflare Turnstile widget and
/// bridges its JS callbacks back to Swift. One shared instance backs every auth flow
/// that needs a captcha token (login, signup, password reset).
///
/// The page is loaded via `loadHTMLString(_:baseURL:)` with `baseURL` set to the prod
/// web domain so `document.location.hostname` resolves to a hostname already
/// allow-listed for this site key in the Cloudflare Turnstile dashboard (the HTML
/// content itself is still local, never fetched over the network).
@MainActor
@Observable
final class TurnstileTokenProvider: NSObject, TurnstileTokenProviding {
  nonisolated deinit {}

  static let shared = TurnstileTokenProvider()

  /// The WKWebView `TurnstileWidgetView` mounts. Created once, lives for the app's lifetime.
  let webView: WKWebView

  @ObservationIgnored private var isWidgetReady = false
  @ObservationIgnored private var pendingContinuation: CheckedContinuation<String, Error>?
  @ObservationIgnored private var readyContinuations: [CheckedContinuation<Void, Never>] = []
  @ObservationIgnored private var hasRetriedAfterExpiry = false

  private override init() {
    let configuration = WKWebViewConfiguration()
    webView = WKWebView(frame: .zero, configuration: configuration)
    super.init()
    configuration.userContentController.add(self, name: "turnstile")
    webView.loadHTMLString(Self.html, baseURL: URL(string: "https://myrecruitingcompass.com"))
  }

  func getToken() async throws -> String {
    hasRetriedAfterExpiry = false
    await waitUntilReady()
    return try await executeChallenge()
  }

  private func waitUntilReady() async {
    if isWidgetReady { return }
    await withCheckedContinuation { continuation in
      readyContinuations.append(continuation)
    }
  }

  private func executeChallenge() async throws -> String {
    try await webView.evaluateJavaScript("window.twReset(); window.twExecute();")
    let timeoutTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(10))
      guard let self, self.pendingContinuation != nil else { return }
      self.pendingContinuation?.resume(throwing: AuthError.captchaFailed)
      self.pendingContinuation = nil
    }
    defer { timeoutTask.cancel() }
    return try await withCheckedThrowingContinuation { continuation in
      pendingContinuation = continuation
    }
  }

  fileprivate func handleReady() {
    isWidgetReady = true
    readyContinuations.forEach { $0.resume() }
    readyContinuations.removeAll()
  }

  fileprivate func handleToken(_ token: String) {
    pendingContinuation?.resume(returning: token)
    pendingContinuation = nil
  }

  fileprivate func handleError() {
    pendingContinuation?.resume(throwing: AuthError.captchaFailed)
    pendingContinuation = nil
  }

  fileprivate func handleExpired() {
    guard !hasRetriedAfterExpiry else {
      pendingContinuation?.resume(throwing: AuthError.captchaFailed)
      pendingContinuation = nil
      return
    }
    hasRetriedAfterExpiry = true
    Task { try? await webView.evaluateJavaScript("window.twReset(); window.twExecute();") }
  }

  private static let html = """
  <!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
  <script src="https://challenges.cloudflare.com/turnstile/v0/api.js?onload=onTurnstileLoad" async defer></script>
  <script>
    var widgetId;
    function onTurnstileLoad() {
      widgetId = turnstile.render('#widget', {
        sitekey: '\(TurnstileConfigEmbedded.siteKey)',
        size: 'invisible',
        callback: function(token) {
          webkit.messageHandlers.turnstile.postMessage({type: 'token', token: token});
        },
        'error-callback': function() {
          webkit.messageHandlers.turnstile.postMessage({type: 'error'});
        },
        'expired-callback': function() {
          webkit.messageHandlers.turnstile.postMessage({type: 'expired'});
        }
      });
      webkit.messageHandlers.turnstile.postMessage({type: 'ready'});
    }
    window.twExecute = function() { if (widgetId) { turnstile.execute(widgetId); } };
    window.twReset = function() { if (widgetId) { turnstile.reset(widgetId); } };
  </script>
  </head><body><div id="widget"></div></body></html>
  """
}

extension TurnstileTokenProvider: WKScriptMessageHandler {
  nonisolated func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
      switch type {
      case "ready":
        self.handleReady()
      case "token":
        if let token = body["token"] as? String {
          self.handleToken(token)
        } else {
          self.handleError()
        }
      case "expired":
        self.handleExpired()
      default:
        self.handleError()
      }
    }
  }
}
