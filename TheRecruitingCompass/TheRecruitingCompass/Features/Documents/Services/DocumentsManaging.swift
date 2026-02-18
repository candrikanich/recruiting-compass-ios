import Foundation

protocol DocumentsManaging: Sendable {
  func fetchDocuments(userId: String) async throws -> [Document]
  func fetchDocument(id: String) async throws -> Document
  func updateDocument(id: String, title: String?, description: String?, schoolId: String?) async throws -> Document
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
  ) async throws -> Document
  func fetchVersionHistory(documentId: String, document: Document) async throws -> [DocumentVersion]
  func updateDocumentIsCurrent(id: String, isCurrent: Bool) async throws
  func shareDocument(documentId: String, schoolId: String) async throws
  func revokeShare(documentId: String, schoolId: String) async throws
  func deleteDocument(id: String, userId: String) async throws
}
