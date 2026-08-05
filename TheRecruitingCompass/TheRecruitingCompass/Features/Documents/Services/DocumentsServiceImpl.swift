import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "DocumentsService")

private struct DocumentUpdatePayload: Encodable {
  let title: String?
  let description: String?
  let schoolId: String?

  enum CodingKeys: String, CodingKey {
    case title, description
    case schoolId = "school_id"
  }
}

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

  func fetchDocument(id: String) async throws -> Document {
    logger.debug("Fetching document: \(id)")

    let document: Document = try await supabaseManager.client
      .from("documents")
      .select()
      .eq("id", value: id)
      .single()
      .execute()
      .value

    logger.info("Fetched document: \(id)")
    return document
  }

  func updateDocument(id: String, title: String?, description: String?, schoolId: String?) async throws -> Document {
    logger.debug("Updating document: \(id)")

    let payload = DocumentUpdatePayload(title: title, description: description, schoolId: schoolId)

    let document: Document = try await supabaseManager.client
      .from("documents")
      .update(payload)
      .eq("id", value: id)
      .select()
      .single()
      .execute()
      .value

    logger.info("Updated document: \(id)")
    return document
  }

  func fetchVersionHistory(documentId: String, document: Document) async throws -> [DocumentVersion] {
    logger.debug("Fetching version history for document: \(documentId)")

    guard let userId = document.userId, !userId.isEmpty else {
      logger.warning("No userId for version history")
      return []
    }

    struct VersionRow: Decodable {
      let id: String
      let version: Int
      let fileUrl: String
      let isCurrent: Bool
      let createdAt: String

      enum CodingKeys: String, CodingKey {
        case id, version, isCurrent
        case fileUrl = "file_url"
        case createdAt = "created_at"
      }
    }

    do {
      let rows: [VersionRow] = try await supabaseManager.client
        .from("documents")
        .select("id, version, file_url, is_current, created_at")
        .eq("document_id", value: documentId)
        .eq("user_id", value: userId)
        .order("version", ascending: false)
        .execute()
        .value
      logger.info("Fetched \(rows.count) versions for document: \(documentId)")
      return rows.map { DocumentVersion(
        id: $0.id,
        version: $0.version,
        fileUrl: $0.fileUrl,
        isCurrent: $0.isCurrent,
        createdAt: $0.createdAt
      ) }
    } catch {
      logger.error("fetchVersionHistory for \(documentId) failed: \(error.localizedDescription)")
      throw error
    }
  }

  func updateDocumentIsCurrent(id: String, isCurrent: Bool) async throws {
    logger.debug("Updating document is_current: \(id) -> \(isCurrent)")

    try await supabaseManager.client
      .from("documents")
      .update(["is_current": isCurrent])
      .eq("id", value: id)
      .execute()

    logger.info("Updated is_current for document: \(id)")
  }

  func shareDocument(documentId: String, schoolId: String) async throws {
    logger.debug("Sharing document: \(documentId) with school: \(schoolId)")

    let document: Document = try await fetchDocument(id: documentId)
    let currentShared = document.sharedWithSchools
    guard !currentShared.contains(schoolId) else {
      logger.info("Document already shared with school")
      return
    }
    let newShared = currentShared + [schoolId]

    try await supabaseManager.client
      .from("documents")
      .update(["shared_with_schools": newShared])
      .eq("id", value: documentId)
      .execute()

    logger.info("Document shared with school")
  }

  func revokeShare(documentId: String, schoolId: String) async throws {
    logger.debug("Revoking share for document: \(documentId) from school: \(schoolId)")

    let document: Document = try await fetchDocument(id: documentId)
    let newShared = document.sharedWithSchools.filter { $0 != schoolId }

    try await supabaseManager.client
      .from("documents")
      .update(["shared_with_schools": newShared])
      .eq("id", value: documentId)
      .execute()

    logger.info("Share revoked")
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

    let timestamp = Int(Date.now.timeIntervalSince1970 * 1000)
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
      do {
        _ = try await supabaseManager.client.storage
          .from("documents")
          .remove(paths: [storagePath])
      } catch {
        logger.error("Failed to remove storage file at path \(storagePath): \(error.localizedDescription)")
      }
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
