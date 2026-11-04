import Foundation
import Supabase

/// Where a stored `documents.file_url` points. Mirrors web's `documentObjectPath` / `isStoragePath`
/// (recruiting-compass-web `utils/storageUrl.ts`), so both platforms accept and reject the same values.
enum DocumentFileLocation: Equatable {
  /// Object path inside the `documents` bucket (bare path, or our own public URL): must be signed to open.
  case storagePath(String)
  /// An http(s) URL on another origin: opens unchanged.
  case external(URL)
  /// Not openable: other schemes, traversal, control characters, or a foreign path on our own origin.
  case rejected

  private static let publicPathPrefix = "/storage/v1/object/public/documents/"
  private static let anyScheme = /^[\u{0}-\u{20}]*[a-z][a-z0-9+.\-]*:/.ignoresCase()

  static func classify(_ raw: String, supabaseOrigin: URL) -> DocumentFileLocation {
    guard !raw.isEmpty else { return .rejected }
    guard isHTTP(raw) else { return isStoragePath(raw) ? .storagePath(raw) : .rejected }
    guard let url = URL(string: raw) else { return .rejected }
    guard sameOrigin(url, supabaseOrigin) else { return .external(url) }
    return publicObjectPath(raw, supabaseOrigin: supabaseOrigin).map(Self.storagePath) ?? .rejected
  }

  private static func isHTTP(_ raw: String) -> Bool {
    let lower = raw.lowercased()
    return lower.hasPrefix("http://") || lower.hasPrefix("https://")
  }

  private static func sameOrigin(_ url: URL, _ origin: URL) -> Bool {
    url.scheme?.lowercased() == origin.scheme?.lowercased()
      && url.host?.lowercased() == origin.host?.lowercased()
      && url.port == origin.port
  }

  /// Exact string prefix, not URL parsing: the parser resolves "%2e%2e" segments, which would turn one
  /// folder's URL into another folder's path.
  private static func publicObjectPath(_ raw: String, supabaseOrigin: URL) -> String? {
    guard let origin = originString(supabaseOrigin), raw.hasPrefix(origin + publicPathPrefix) else { return nil }
    let tail = raw.dropFirst(origin.count + publicPathPrefix.count)
    let encoded = tail.prefix { $0 != "?" && $0 != "#" }
    guard let path = String(encoded).removingPercentEncoding, isStoragePath(path) else { return nil }
    return path
  }

  private static func originString(_ url: URL) -> String? {
    guard let scheme = url.scheme, let host = url.host else { return nil }
    return "\(scheme)://\(host)" + (url.port.map { ":\($0)" } ?? "")
  }

  private static func isStoragePath(_ value: String) -> Bool {
    let stripped = value.filter { !"\t\n\r".contains($0) }
    return !value.isEmpty
      && !value.unicodeScalars.contains { $0.value < 0x20 || $0.value == 0x7F || $0 == "?" || $0 == "#" }
      && stripped.firstMatch(of: anyScheme) == nil
      && !hasDotSegment(value)
  }

  private static func hasDotSegment(_ path: String) -> Bool {
    path.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "/" || $0 == "\\" }).contains { segment in
      guard let decoded = String(segment).removingPercentEncoding else { return true }
      let visible = decoded.filter { !"\t\n\r".contains($0) }
      return visible == "." || visible == ".."
    }
  }
}

enum DocumentURLError: Error {
  case notOpenable
}

/// Turns a stored `file_url` into a URL that is safe to open. Storage paths are signed (the bucket goes
/// private in web#1590 step 3); there is deliberately no unsigned fallback when signing fails.
protocol DocumentURLResolving: Sendable {
  func openableURL(for fileUrl: String) async throws -> URL
}

struct DocumentURLResolver: DocumentURLResolving {
  static let signedURLTTLSeconds = 3600

  let supabaseOrigin: URL
  let sign: @Sendable (_ objectPath: String) async throws -> URL

  init(
    supabaseOrigin: URL = SupabaseConfig.url,
    sign: @escaping @Sendable (_ objectPath: String) async throws -> URL = { path in
      try await SupabaseManager.shared.client.storage
        .from("documents")
        .createSignedURL(path: path, expiresIn: DocumentURLResolver.signedURLTTLSeconds)
    }
  ) {
    self.supabaseOrigin = supabaseOrigin
    self.sign = sign
  }

  func openableURL(for fileUrl: String) async throws -> URL {
    switch DocumentFileLocation.classify(fileUrl, supabaseOrigin: supabaseOrigin) {
    case .external(let url):
      return url
    case .storagePath(let path):
      let signed = try await sign(path)
      guard ["http", "https"].contains(signed.scheme?.lowercased()) else { throw DocumentURLError.notOpenable }
      return signed
    case .rejected:
      throw DocumentURLError.notOpenable
    }
  }
}
