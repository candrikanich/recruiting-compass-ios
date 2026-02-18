import Foundation

protocol DocumentsManaging: Sendable {
  func fetchDocuments(userId: String) async throws -> [Document]
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
  func deleteDocument(id: String, userId: String) async throws
}
