#if DEBUG
import Foundation

/// Decides when a DEBUG build skips the Cloudflare challenge and sends Supabase a placeholder
/// token. Both cases below target stacks that have captcha disabled and ignore the token; a
/// stack that enforces captcha (prod) rejects the placeholder, so a wrong answer here fails
/// the login instead of weakening it.
enum CaptchaBypassPolicy {
  private static let loopbackHosts: Set<String> = ["localhost", "127.0.0.1", "::1"]

  static func shouldBypass(
    arguments: [String],
    supabaseHost: String?,
    isUITestBackendOverride: Bool
  ) -> Bool {
    // Local Supabase stack (App Store screenshot capture, marketing clips).
    let isLocalBypass = arguments.contains("--local-captcha-bypass")
      && loopbackHosts.contains(supabaseHost ?? "")
    // CI E2E against the throwaway remote project: a hosted runner never completes the
    // invisible challenge. Only honored when the UI-test launch environment supplied the
    // backend, so the embedded (prod) project is never handed the placeholder.
    let isE2EBypass = arguments.contains("--e2e-captcha-bypass") && isUITestBackendOverride
    return isLocalBypass || isE2EBypass
  }
}
#endif
