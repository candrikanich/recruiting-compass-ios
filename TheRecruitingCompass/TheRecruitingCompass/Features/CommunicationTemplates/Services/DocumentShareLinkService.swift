import Foundation
import Supabase

/// What a stored `documents.file_url` may become in a coach message (parity with web
/// `documentObjectPath` in utils/storageUrl.ts, web#1600): a share link for a file in our
/// `documents` bucket, the URL itself for an external link, nothing for anything else.
enum DocumentLinkTarget: Equatable {
  case storage
  case external(String)
  case none

  private static let publicBucketPath = "/storage/v1/object/public/documents/"

  static func classify(fileURL: String?, supabaseOrigin: String) -> DocumentLinkTarget {
    guard let raw = fileURL, !raw.isEmpty else { return .none }
    if isHttpURL(raw) {
      if let path = ownBucketObjectPath(raw, supabaseOrigin: supabaseOrigin) {
        return isStoragePath(path) ? .storage : .none
      }
      return isOnOrigin(raw, origin: supabaseOrigin) ? .none : .external(raw)
    }
    return isStoragePath(raw) ? .storage : .none
  }

  /// Exact string prefix, not URL parsing: the parser resolves "%2e%2e" segments, which would
  /// turn one folder's URL into another folder's path.
  private static func ownBucketObjectPath(_ raw: String, supabaseOrigin: String) -> String? {
    guard !supabaseOrigin.isEmpty else { return nil }
    let prefix = supabaseOrigin + publicBucketPath
    guard raw.hasPrefix(prefix) else { return nil }
    let encoded = raw.dropFirst(prefix.count).prefix { $0 != "?" && $0 != "#" }
    return String(encoded).removingPercentEncoding ?? ""
  }

  private static func isHttpURL(_ raw: String) -> Bool {
    guard let url = URL(string: raw), let scheme = url.scheme?.lowercased() else { return false }
    return (scheme == "http" || scheme == "https") && url.host?.isEmpty == false
  }

  private static func isOnOrigin(_ raw: String, origin: String) -> Bool {
    guard let url = URL(string: raw), let scheme = url.scheme, let host = url.host,
          let originURL = URL(string: origin), let originHost = originURL.host else { return false }
    return scheme.lowercased() == originURL.scheme?.lowercased()
      && host.lowercased() == originHost.lowercased() && url.port == originURL.port
  }

  /// A bare, non-traversing object path: no scheme, control characters, `?`/`#`, or dot segments.
  static func isStoragePath(_ value: String) -> Bool {
    guard !value.isEmpty else { return false }
    let stripped = value.filter { !"\t\n\r".contains($0) }
    if stripped.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F || $0 == "?" || $0 == "#" }) {
      return false
    }
    if stripped.range(of: "^[\\u{0}-\\u{20}]*[A-Za-z][A-Za-z0-9+.-]*:", options: .regularExpression) != nil {
      return false
    }
    return !value.split(whereSeparator: { $0 == "/" || $0 == "\\" }).contains { segment in
      guard let decoded = String(segment).removingPercentEncoding else { return true }
      let cleaned = decoded.filter { !"\t\n\r".contains($0) }
      return cleaned == "." || cleaned == ".."
    }
  }
}

enum DocumentShareTokenError: Error {
  case uniqueViolation
  case other
}

protocol DocumentShareTokenStoring: Sendable {
  /// Tokens of the document's non-revoked rows, newest first.
  func activeTokens(documentId: String) async throws -> [String]
  /// Inserts `{ document_id }` only; the server assigns token, family and creator.
  func insertToken(documentId: String) async throws -> String
}

struct SupabaseDocumentShareTokenStore: DocumentShareTokenStoring {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager = .shared) {
    self.supabaseManager = supabaseManager
  }

  private struct TokenRow: Decodable { let token: String }
  private struct NewToken: Encodable {
    let documentId: String
    enum CodingKeys: String, CodingKey { case documentId = "document_id" }
  }

  func activeTokens(documentId: String) async throws -> [String] {
    let rows: [TokenRow] = try await supabaseManager.client
      .from("document_share_tokens").select("token")
      .eq("document_id", value: documentId).is("revoked_at", value: nil)
      .order("created_at", ascending: false).execute().value
    return rows.map(\.token)
  }

  func insertToken(documentId: String) async throws -> String {
    do {
      let row: TokenRow = try await supabaseManager.client
        .from("document_share_tokens").insert(NewToken(documentId: documentId))
        .select("token").single().execute().value
      return row.token
    } catch let error as PostgrestError where error.code == "23505" {
      throw DocumentShareTokenError.uniqueViolation
    }
  }
}

/// Issues the revocable `/d/<token>` link a coach receives instead of a raw storage URL (web#1600).
struct DocumentShareLinkService: Sendable {
  /// Absolute so the link is clickable in the email/SMS sent to a coach.
  static let linkBase = "https://myrecruitingcompass.com"

  private let store: any DocumentShareTokenStoring

  init(store: any DocumentShareTokenStoring = SupabaseDocumentShareTokenStore()) {
    self.store = store
  }

  /// The document's active link, issuing one first if there is none.
  func shareURL(documentId: String) async throws -> String {
    if let existing = try await store.activeTokens(documentId: documentId).first {
      return Self.url(token: existing)
    }
    do {
      return Self.url(token: try await store.insertToken(documentId: documentId))
    } catch DocumentShareTokenError.uniqueViolation {
      // Another send won the race: the partial unique index allows one active token.
      if let winner = try await store.activeTokens(documentId: documentId).first {
        return Self.url(token: winner)
      }
      throw DocumentShareTokenError.uniqueViolation
    }
  }

  /// The link for a coach message, or nil (never the bucket URL) when none can be issued.
  func linkForDocument(id: String, fileURL: String?, supabaseOrigin: String) async -> String? {
    switch DocumentLinkTarget.classify(fileURL: fileURL, supabaseOrigin: supabaseOrigin) {
    case .storage: return try? await shareURL(documentId: id)
    case .external(let url): return url
    case .none: return nil
    }
  }

  private static func url(token: String) -> String { "\(linkBase)/d/\(token)" }
}
