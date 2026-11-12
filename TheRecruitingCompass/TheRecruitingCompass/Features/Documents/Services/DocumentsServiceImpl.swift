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

struct DocumentInsertPayload: Encodable, Equatable {
  let userId: String
  let familyUnitId: String?
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

  func with(fileUrl: String) -> DocumentInsertPayload {
    DocumentInsertPayload(
      userId: userId, familyUnitId: familyUnitId, uploadedBy: uploadedBy, type: type, title: title,
      description: description, fileUrl: fileUrl, fileType: fileType, version: version, schoolId: schoolId,
      isCurrent: isCurrent, sharedWithSchools: sharedWithSchools)
  }

  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case familyUnitId = "family_unit_id"
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
  private let client: SupabaseClient

  init(client: SupabaseClient) {
    self.client = client
  }

  convenience init(supabaseManager: SupabaseManager = .shared) {
    self.init(client: supabaseManager.client)
  }

  /// Family-wide: a document another member uploaded (web stamps `user_id` with the uploader) belongs in the
  /// list too. RLS ("Users can view documents in their families") bounds what a family id can return.
  func fetchDocuments(familyUnitId: String) async throws -> [Document] {
    logger.debug("Fetching documents for family: \(familyUnitId)")

    let documents: [Document] = try await client
      .from("documents")
      .select()
      .eq("family_unit_id", value: familyUnitId)
      .order("created_at", ascending: false)
      .execute()
      .value

    logger.info("Fetched \(documents.count) documents")
    return documents
  }

  func fetchDocument(id: String) async throws -> Document {
    logger.debug("Fetching document: \(id)")

    let document: Document = try await client
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

    let document: Document = try await client
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

    guard let scope = VersionScope(document: document) else {
      logger.warning("No family or user for version history")
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
      let rows: [VersionRow] = try await client
        .from("documents")
        .select("id, version, file_url, is_current, created_at")
        .eq("document_id", value: documentId)
        .eq(scope.column, value: scope.value)
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

    try await client
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

    try await client
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

    try await client
      .from("documents")
      .update(["shared_with_schools": newShared])
      .eq("id", value: documentId)
      .execute()

    logger.info("Share revoked")
  }

  func uploadDocument(
    userId: String,
    uploadedBy: String,
    file: Data,
    fileName: String,
    mimeType: String,
    type: DocumentType,
    title: String,
    description: String?,
    schoolId: String?,
    version: Int,
    familyUnitId: String?
  ) async throws -> Document {
    logger.debug("Uploading document: \(title) type: \(type.rawValue)")

    let timestamp = Int(Date.now.timeIntervalSince1970 * 1000)
    let plan = Self.uploadPlan(
      userId: userId, uploadedBy: uploadedBy, familyUnitId: familyUnitId, type: type, timestamp: timestamp,
      fileName: fileName, mimeType: mimeType, title: title, description: description,
      schoolId: schoolId, version: version
    )

    _ = try await client.storage
      .from("documents")
      .upload(
        plan.path,
        data: file,
        options: FileOptions(cacheControl: "3600", contentType: mimeType)
      )

    let urlResponse = try client.storage
      .from("documents")
      .getPublicURL(path: plan.path)
    let publicURL = urlResponse.absoluteURL

    let payload = plan.payload(fileUrl: publicURL.absoluteString)

    let document: Document = try await client
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

    let document: Document = try await client
      .from("documents")
      .select()
      .eq("id", value: id)
      .eq("user_id", value: userId)
      .single()
      .execute()
      .value

    if let storagePath = Self.storageObjectPath(forDeleting: document.fileUrl, supabaseOrigin: SupabaseConfig.url) {
      do {
        _ = try await client.storage
          .from("documents")
          .remove(paths: [storagePath])
      } catch {
        logger.error("Failed to remove storage file at path \(storagePath): \(error.localizedDescription)")
      }
    }

    try await client
      .from("documents")
      .delete()
      .eq("id", value: id)
      .eq("user_id", value: userId)
      .execute()

    logger.info("Deleted document: \(id)")
  }

  /// Versions of a document are listed family-wide like the list itself; rows that predate `family_unit_id`
  /// fall back to their uploader.
  struct VersionScope: Equatable {
    let column: String
    let value: String

    init?(document: Document) {
      if let familyUnitId = FamilyUnitID.normalized(document.familyUnitId) {
        self.init(column: "family_unit_id", value: familyUnitId)
      } else if let userId = document.userId, !userId.isEmpty {
        self.init(column: "user_id", value: userId)
      } else {
        return nil
      }
    }

    private init(column: String, value: String) {
      self.column = column
      self.value = value
    }
  }

  /// Where an upload lands and what row describes it. The storage INSERT policy only admits `auth.uid()` as the
  /// first folder, so a parent uploading for an athlete stores under their own uid while the row's `user_id`
  /// stays the athlete's (web `useDocumentUpload`). All of that lives here so it can be tested without a network.
  struct UploadPlan: Equatable {
    let path: String
    private let draft: DocumentInsertPayload

    fileprivate init(path: String, draft: DocumentInsertPayload) {
      self.path = path
      self.draft = draft
    }

    func payload(fileUrl: String) -> DocumentInsertPayload { draft.with(fileUrl: fileUrl) }
  }

  static func uploadPlan(
    userId: String, uploadedBy: String, familyUnitId: String?, type: DocumentType, timestamp: Int,
    fileName: String, mimeType: String, title: String, description: String?, schoolId: String?, version: Int
  ) -> UploadPlan {
    let draft = DocumentInsertPayload(
      userId: userId,
      familyUnitId: FamilyUnitID.normalized(familyUnitId),
      uploadedBy: uploadedBy,
      type: type.rawValue,
      title: title,
      description: description,
      fileUrl: "",
      fileType: mimeType,
      version: version,
      schoolId: schoolId,
      isCurrent: true,
      sharedWithSchools: []
    )
    let key = "\(uploadedBy)/\(type.rawValue)/\(timestamp)_\(StorageKey.safeFileName(fileName))"
    return UploadPlan(path: key, draft: draft)
  }

  /// The object this row owns, or nil when none may be removed. Uses the viewer's classifier so bare paths
  /// (everything uploaded on web) and our own public URLs resolve, while traversal and foreign values never do.
  static func storageObjectPath(forDeleting fileUrl: String, supabaseOrigin: URL) -> String? {
    guard case .storagePath(let path) = DocumentFileLocation.classify(fileUrl, supabaseOrigin: supabaseOrigin) else {
      return nil
    }
    return path
  }
}
