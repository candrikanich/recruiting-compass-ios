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

  var stubbedDocuments: [Document] = []
  var stubbedUploadedDocument: Document?

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
