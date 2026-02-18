import Foundation
@testable import TheRecruitingCompass

final class MockDocumentsService: DocumentsManaging, @unchecked Sendable {

  var fetchDocumentsCallCount = 0
  var uploadDocumentCallCount = 0
  var deleteDocumentCallCount = 0

  var lastFetchDocumentsUserId: String?
  var lastUploadDocumentUserId: String?
  var lastUploadDocumentTitle: String?
  var lastUploadDocumentType: DocumentType?
  var lastDeleteDocumentId: String?
  var lastDeleteDocumentUserId: String?

  var shouldThrowFetchDocuments = false
  var shouldThrowUploadDocument = false
  var shouldThrowDeleteDocument = false
  var shouldThrowFetchDocument = false
  var fetchDocumentErrorCode: Int = 8
  var shouldThrowUpdateDocument = false
  var shouldThrowFetchVersionHistory = false
  var shouldThrowShareDocument = false
  var shouldThrowRevokeShare = false
  var shouldThrowUpdateDocumentIsCurrent = false

  var updateDocumentIsCurrentCallCount = 0
  var lastUpdateDocumentIsCurrentId: String?
  var lastUpdateDocumentIsCurrentValue: Bool?

  var stubbedDocuments: [Document] = []
  var stubbedUploadedDocument: Document?
  var stubbedDocument: Document?
  var stubbedVersions: [DocumentVersion] = []

  func fetchDocuments(userId: String) async throws -> [Document] {
    fetchDocumentsCallCount += 1
    lastFetchDocumentsUserId = userId
    if shouldThrowFetchDocuments {
      throw NSError(domain: "MockDocumentsService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Mock fetch error"])
    }
    return stubbedDocuments
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
    uploadDocumentCallCount += 1
    lastUploadDocumentUserId = userId
    lastUploadDocumentTitle = title
    lastUploadDocumentType = type
    if shouldThrowUploadDocument {
      throw NSError(domain: "MockDocumentsService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Mock upload error"])
    }
    guard let doc = stubbedUploadedDocument else {
      return Document.mock(id: "uploaded-1", title: title, type: type)
    }
    return doc
  }

  func fetchDocument(id: String) async throws -> Document {
    if shouldThrowFetchDocument {
      throw NSError(domain: "MockDocumentsService", code: fetchDocumentErrorCode, userInfo: [NSLocalizedDescriptionKey: "Document not found"])
    }
    if let doc = stubbedDocument { return doc }
    return stubbedDocuments.first { $0.id == id } ?? Document.mock(id: id, title: "Test", type: .highlightVideo)
  }

  func updateDocument(id: String, title: String?, description: String?, schoolId: String?) async throws -> Document {
    if shouldThrowUpdateDocument {
      throw NSError(domain: "MockDocumentsService", code: 9, userInfo: [NSLocalizedDescriptionKey: "Mock update error"])
    }
    let base = stubbedDocument ?? stubbedDocuments.first { $0.id == id } ?? Document.mock(id: id)
    return Document(
      id: base.id,
      userId: base.userId,
      type: base.type,
      title: title ?? base.title,
      description: description ?? base.description,
      fileUrl: base.fileUrl,
      fileType: base.fileType,
      version: base.version,
      schoolId: schoolId ?? base.schoolId,
      isCurrent: base.isCurrent,
      sharedWithSchools: base.sharedWithSchools,
      uploadedBy: base.uploadedBy,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt
    )
  }

  func fetchVersionHistory(documentId: String, document: Document) async throws -> [DocumentVersion] {
    if shouldThrowFetchVersionHistory {
      throw NSError(domain: "MockDocumentsService", code: 10, userInfo: [NSLocalizedDescriptionKey: "Mock version history error"])
    }
    return stubbedVersions
  }

  func updateDocumentIsCurrent(id: String, isCurrent: Bool) async throws {
    updateDocumentIsCurrentCallCount += 1
    lastUpdateDocumentIsCurrentId = id
    lastUpdateDocumentIsCurrentValue = isCurrent
    if shouldThrowUpdateDocumentIsCurrent {
      throw NSError(domain: "MockDocumentsService", code: 13, userInfo: [NSLocalizedDescriptionKey: "Mock restore error"])
    }
  }

  func shareDocument(documentId: String, schoolId: String) async throws {
    if shouldThrowShareDocument {
      throw NSError(domain: "MockDocumentsService", code: 11, userInfo: [NSLocalizedDescriptionKey: "Mock share error"])
    }
  }

  func revokeShare(documentId: String, schoolId: String) async throws {
    if shouldThrowRevokeShare {
      throw NSError(domain: "MockDocumentsService", code: 12, userInfo: [NSLocalizedDescriptionKey: "Mock revoke error"])
    }
  }

  func deleteDocument(id: String, userId: String) async throws {
    deleteDocumentCallCount += 1
    lastDeleteDocumentId = id
    lastDeleteDocumentUserId = userId
    if shouldThrowDeleteDocument {
      throw NSError(domain: "MockDocumentsService", code: 7, userInfo: [NSLocalizedDescriptionKey: "Mock delete error"])
    }
  }
}

// MARK: - Document test helper

extension Document {
  static func mock(
    id: String = "doc-1",
    title: String = "Test Document",
    type: DocumentType = .highlightVideo,
    description: String? = nil,
    schoolId: String? = nil,
    sharedWithSchools: [String] = [],
    createdAt: String? = "2026-02-17T00:00:00Z"
  ) -> Document {
    Document(
      id: id,
      userId: "user-1",
      type: type,
      title: title,
      description: description,
      fileUrl: "https://example.com/file.mp4",
      fileType: "video/mp4",
      version: 1,
      schoolId: schoolId,
      isCurrent: true,
      sharedWithSchools: sharedWithSchools,
      uploadedBy: "user-1",
      createdAt: createdAt,
      updatedAt: "2026-02-17T00:00:00Z"
    )
  }
}
