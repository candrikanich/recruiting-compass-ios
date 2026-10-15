import Combine
import Foundation
import OSLog
import Sentry
import WebKit

/// Unified log (not `print`) so failures are readable from a Release build via Console or `log show`,
/// plus Sentry so failures on devices we don't hold (App Review rejected 1.0 twice on this) are visible.
private struct TurnstileLog {
  private let logger = Logger(subsystem: "com.recruitingcompass", category: "Turnstile")
  func error(_ message: String) {
    logger.error("[Turnstile] \(message, privacy: .public)")
    SentrySDK.capture(message: "[Turnstile] \(message)")
  }
}

/// Owns the single WKWebView that runs the Cloudflare Turnstile widget and bridges its JS
/// callbacks back to Swift. One shared instance backs every auth flow that needs a captcha
/// token (login, signup, password reset).
///
/// The site key is a Managed widget: most devices pass without seeing anything, but Cloudflare
/// can demand a checkbox tap. The web view therefore stays a hidden 1×1 view until the widget
/// reports it needs interaction, then `isChallengeVisible` flips and `TurnstileChallengeOverlay`
/// shows it. Keeping it hidden unconditionally left an unsolvable challenge that timed out as
/// "Couldn't verify you're human" (iPad App Review rejection, 2026-10-15).
///
/// The page is loaded via `loadHTMLString(_:baseURL:)` with `baseURL` set to the prod
/// web domain so `document.location.hostname` resolves to a hostname already
/// allow-listed for this site key in the Cloudflare Turnstile dashboard (the HTML
/// content itself is still local, never fetched over the network).
@MainActor
final class TurnstileTokenProvider: NSObject, ObservableObject, TurnstileTokenProviding {
  nonisolated deinit {}

  static let shared = TurnstileTokenProvider()

  /// No-interaction challenges finish in a couple of seconds; a person solving the checkbox needs longer.
  private static let tokenTimeout: Duration = .seconds(10)
  private static let interactiveTimeout: Duration = .seconds(120)

  /// The WKWebView `TurnstileWidgetView` mounts. Created once, lives for the app's lifetime.
  let webView: WKWebView

  /// True while Cloudflare is waiting for the user to complete an interactive challenge.
  @Published private(set) var isChallengeVisible = false

  private var isWidgetReady = false
  private var pendingContinuation: CheckedContinuation<String, Error>?
  private var tokenTimeoutTask: Task<Void, Never>?
  private var readyContinuations: [CheckedContinuation<Void, Error>] = []
  private var readyTimeoutTask: Task<Void, Never>?
  private var hasRetriedAfterExpiry = false
  private static let log = TurnstileLog()

  private override init() {
    let configuration = WKWebViewConfiguration()
    // iPadOS defaults to desktop-class content (Mac UA), which Turnstile can score as riskier.
    configuration.defaultWebpagePreferences.preferredContentMode = .mobile
    webView = WKWebView(frame: .zero, configuration: configuration)
    super.init()
    configuration.userContentController.add(self, name: "turnstile")
    webView.navigationDelegate = self
    loadWidget()
  }

  /// Loads (or reloads) the widget HTML. Called from `init` and from the navigation-delegate
  /// recovery paths below so a failed load or a terminated content process can be retried.
  private func loadWidget() {
    webView.loadHTMLString(Self.html, baseURL: URL(string: "https://myrecruitingcompass.com"))
  }

  #if DEBUG
  /// The local Supabase stack used for App Store screenshot capture has captcha disabled and can't
  /// complete a real Cloudflare challenge, so it ignores the token. Opt-in via a dedicated launch flag
  /// and only when Supabase is a loopback host, so no remote stack is ever handed a fake token.
  private static var shouldBypassCaptcha: Bool {
    CaptchaBypassPolicy.shouldBypass(
      arguments: ProcessInfo.processInfo.arguments,
      supabaseHost: SupabaseConfig.url.host,
      isUITestBackendOverride: SupabaseConfig.isUITestBackendOverride
    )
  }
  #endif

  func getToken() async throws -> String {
    #if DEBUG
    if Self.shouldBypassCaptcha { return "local-captcha-bypass" }
    #endif
    hasRetriedAfterExpiry = false
    try await waitUntilReady()
    return try await executeChallenge()
  }

  /// Waits for the widget's "ready" postMessage, or throws `.captchaFailed` after 10s if
  /// `api.js` never loads (blocked network, unreachable Cloudflare, etc). Multiple callers
  /// can queue on the same wait; a single shared timeout task covers all of them and is
  /// cancelled the moment `handleReady()` fires.
  private func waitUntilReady() async throws {
    if isWidgetReady { return }
    if readyTimeoutTask == nil {
      readyTimeoutTask = Task { @MainActor [weak self] in
        try? await Task.sleep(for: .seconds(10))
        guard let self, !self.isWidgetReady else { return }
        let waiters = self.readyContinuations
        self.readyContinuations.removeAll()
        self.readyTimeoutTask = nil
        Self.log.error("Turnstile widget not ready after 10s")
        waiters.forEach { $0.resume(throwing: AuthError.captchaFailed) }
      }
    }
    try await withCheckedThrowingContinuation { continuation in
      readyContinuations.append(continuation)
    }
  }

  /// Installs the continuation before kicking off `twReset()/twExecute()` so a callback
  /// that fires immediately (fast/cached challenge) always has somewhere to land — never
  /// runs `evaluateJavaScript` first and then races it against continuation setup.
  private func executeChallenge() async throws -> String {
    // Single-flight: this app never runs two captcha challenges concurrently. Superseding
    // a still-pending call (rather than leaking its continuation) is correct behavior here.
    if pendingContinuation != nil {
      Self.log.error("Turnstile challenge superseded by a newer request")
      failPending()
    }

    return try await withCheckedThrowingContinuation { continuation in
      pendingContinuation = continuation
      armTokenTimeout(Self.tokenTimeout)
      Task { @MainActor [weak self] in
        guard let self else { return }
        do {
          try await self.webView.evaluateJavaScript("window.twReset(); window.twExecute(); null;")
        } catch {
          Self.log.error("Turnstile evaluateJavaScript failed: \(error.localizedDescription)")
          // A JS-evaluation failure must still surface as `.captchaFailed`, not the raw WKError.
          self.failPending()
        }
      }
    }
  }

  /// Replaces any running timeout, so a stale timer can never fail a newer challenge or cut off
  /// a user who is mid-way through an interactive one.
  private func armTokenTimeout(_ timeout: Duration) {
    tokenTimeoutTask?.cancel()
    tokenTimeoutTask = Task { @MainActor [weak self] in
      do { try await Task.sleep(for: timeout) } catch { return }
      guard let self, self.pendingContinuation != nil else { return }
      Self.log.error("Turnstile token timeout after \(timeout) (interactive: \(self.isChallengeVisible))")
      self.failPending()
    }
  }

  private func finishChallenge() {
    tokenTimeoutTask?.cancel()
    tokenTimeoutTask = nil
    pendingContinuation = nil
    isChallengeVisible = false
  }

  /// No-op when nothing is pending, so a late callback after a timeout or cancel is harmless.
  private func failPending() {
    let continuation = pendingContinuation
    finishChallenge()
    continuation?.resume(throwing: AuthError.captchaFailed)
  }

  /// The user dismissed the interactive challenge instead of solving it.
  func cancelChallenge() {
    guard pendingContinuation != nil else { return }
    Self.log.error("Turnstile interactive challenge cancelled by user")
    failPending()
  }

  fileprivate func handleReady() {
    isWidgetReady = true
    readyTimeoutTask?.cancel()
    readyTimeoutTask = nil
    readyContinuations.forEach { $0.resume() }
    readyContinuations.removeAll()
  }

  fileprivate func handleToken(_ token: String) {
    let continuation = pendingContinuation
    finishChallenge()
    continuation?.resume(returning: token)
  }

  fileprivate func handleError(code: String?) {
    Self.log.error("Turnstile error-callback code=\(code ?? "none")")
    failPending()
  }

  fileprivate func handleInteractionRequired() {
    guard pendingContinuation != nil else { return }
    isChallengeVisible = true
    armTokenTimeout(Self.interactiveTimeout)
  }

  fileprivate func handleExpired() {
    Self.log.error("Turnstile expired-callback (already retried: \(self.hasRetriedAfterExpiry))")
    guard !hasRetriedAfterExpiry else {
      failPending()
      return
    }
    hasRetriedAfterExpiry = true
    Task { try? await webView.evaluateJavaScript("window.twReset(); window.twExecute(); null;") }
  }

  // `appearance: 'interaction-only'` keeps the widget blank unless Cloudflare needs a tap, and
  // `before-interactive-callback` is what tells Swift to show it. (`size: 'invisible'`, used
  // before, is not a Turnstile option.)
  private static let html = """
  <!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
  <style>html, body { margin: 0; padding: 0; background: transparent; }</style>
  <script src="https://challenges.cloudflare.com/turnstile/v0/api.js?onload=onTurnstileLoad" async defer></script>
  <script>
    var widgetId;
    function post(message) { webkit.messageHandlers.turnstile.postMessage(message); }
    function onTurnstileLoad() {
      widgetId = turnstile.render('#widget', {
        sitekey: '\(TurnstileConfigEmbedded.siteKey)',
        appearance: 'interaction-only',
        execution: 'execute',
        callback: function(token) { post({type: 'token', token: token}); },
        'error-callback': function(code) { post({type: 'error', code: String(code)}); },
        'expired-callback': function() { post({type: 'expired'}); },
        'before-interactive-callback': function() { post({type: 'interactive'}); },
        'unsupported-callback': function() { post({type: 'error', code: 'unsupported'}); }
      });
      post({type: 'ready'});
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
          self.handleError(code: "missing-token")
        }
      case "interactive":
        self.handleInteractionRequired()
      case "expired":
        self.handleExpired()
      case "error":
        self.handleError(code: body["code"] as? String)
      default:
        self.handleError(code: "unknown-message-\(type)")
      }
    }
  }
}

extension TurnstileTokenProvider: WKNavigationDelegate {
  /// Recovery path for a page load that fails outright (e.g. no network on cold launch).
  /// Without this, `isWidgetReady` would simply never flip to `true` and every future
  /// `getToken()` call would time out for the rest of the app session.
  nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      self.isWidgetReady = false
      self.loadWidget()
    }
  }

  /// Same recovery as `didFail`, but for a failure that occurs before the page commits
  /// (e.g. the initial HTML load itself never starts due to no network).
  nonisolated func webView(
    _ webView: WKWebView,
    didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      self.isWidgetReady = false
      self.loadWidget()
    }
  }

  /// iOS can jetsam the WKWebView's content process at any time — including while this
  /// webview is unmounted (backgrounded auth flows are a plausible jetsam target). Without
  /// this, `isWidgetReady` would stay `true` for a page that no longer exists, and every
  /// future `getToken()` would silently fail forever.
  nonisolated func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      self.isWidgetReady = false
      self.loadWidget()
    }
  }
}
