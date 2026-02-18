import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "DocumentsService")

private struct DocumentInsertPayload: Encodable {
  let userId: String
  let uploadedBy: String
  let type: String
  let title: String
  let description: String?
  let fileUrl: String
  let fileType: String
  let version: Int
  let schoolId: String?
  let isCurrent: Bool
  let sharedWithSchools: [String]

  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case uploadedBy = "uploaded_by"
    case type, title, description
    case fileUrl = "file_url"
    case fileType = "file_type"
    case version
    case schoolId = "school_id"
    case isCurrent = "is_current"
    case sharedWithSchools = "shared_with_schools"
  }
}

final class DocumentsServiceImpl: DocumentsManaging, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager = .shared) {
    self.supabaseManager = supabaseManager
  }

  func fetchDocuments(userId: String) async throws -> [Document] {
    logger.debug("Fetching documents for user: \(userId)")

    let documents: [Document] = try await supabaseManager.client
      .from("documents")
      .select()
      .eq("user_id", value: userId)
      .order("created_at", ascending: false)
      .execute()
      .value

    logger.info("Fetched \(documents.count) documents")
    return documents
  }

  func uploadDocument(
    userId: String,
    file: Data,
    fileName: String,
    mimeType: String,
    type: DocumentType,
    title: String,
    description: String?,
    schoolId: String?,
    version: Int
  ) async throws -> Document {
    logger.debug("Uploading document: \(title) type: \(type.rawValue)")

    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
    let storagePath = "\(userId)/\(type.rawValue)/\(timestamp)_\(fileName)"

    _ = try await supabaseManager.client.storage
      .from("documents")
      .upload(
        storagePath,
        data: file,
        options: FileOptions(cacheControl: "3600", contentType: mimeType)
      )

    let urlResponse = try supabaseManager.client.storage
      .from("documents")
      .getPublicURL(path: storagePath)
    let publicURL = urlResponse.absoluteURL

    let payload = DocumentInsertPayload(
      userId: userId,
      uploadedBy: userId,
      type: type.rawValue,
      title: title,
      description: description,
      fileUrl: publicURL.absoluteString,
      fileType: mimeType,
      version: version,
      schoolId: schoolId,
      isCurrent: true,
      sharedWithSchools: []
    )

    let document: Document = try await supabaseManager.client
      .from("documents")
      .insert(payload)
      .select()
      .single()
      .execute()
      .value

    logger.info("Uploaded document: \(document.id)")
    return document
  }

  func deleteDocument(id: String, userId: String) async throws {
    logger.debug("Deleting document: \(id)")

    let document: Document = try await supabaseManager.client
      .from("documents")
      .select()
      .eq("id", value: id)
      .eq("user_id", value: userId)
      .single()
      .execute()
      .value

    if !document.fileUrl.isEmpty, let storagePath = extractStoragePath(from: document.fileUrl) {
      _ = try? await supabaseManager.client.storage
        .from("documents")
        .remove(paths: [storagePath])
    }

    try await supabaseManager.client
      .from("documents")
      .delete()
      .eq("id", value: id)
      .eq("user_id", value: userId)
      .execute()

    logger.info("Deleted document: \(id)")
  }

  /// Extracts bucket path from Supabase public URL.
  /// e.g. "https://x.supabase.co/storage/v1/object/public/documents/user/type/file.pdf" -> "user/type/file.pdf"
  private func extractStoragePath(from fileUrl: String) -> String? {
    guard let url = URL(string: fileUrl) else { return nil }
    let path = url.path
    let prefix = "/storage/v1/object/public/documents/"
    guard path.hasPrefix(prefix) else { return nil }
    return String(path.dropFirst(prefix.count))
  }
}
