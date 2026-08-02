import Foundation
import Observation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "DocumentDetailViewModel"
)

@Observable
@MainActor
final class DocumentDetailViewModel {

  nonisolated deinit {}

  // MARK: - State

  var document: Document?
  var versions: [DocumentVersion] = []
  var schools: [School] = []
  var isLoading = false
  var error: String?
  var isNotFound = false
  var shouldDismiss = false

  // MARK: - Edit State

  var showEditSheet = false
  var editTitle = ""
  var editDescription = ""
  var editSchoolId: String?
  var isSaving = false

  // MARK: - Share State

  var showShareModal = false
  var selectedSchoolIds: Set<String> = []

  // MARK: - Version State

  var isUploadingNewVersion = false
  var uploadProgress: Double = 0
  var showRestoreConfirmation = false
  var versionToRestore: DocumentVersion?

  // MARK: - Delete State

  var showDeleteConfirmation = false
  var isDeleting = false

  // MARK: - Dependencies

  private let documentsService: any DocumentsManaging
  private let schoolsService: any SchoolsManaging
  private let authManager: any AuthManaging
  private let familyManager: FamilyManager
  private let cache: (any CacheManaging)?

  private static let documentCacheTTL: TimeInterval = 60

  let documentId: String

  // MARK: - Computed

  /// The user whose document we read/write. When a parent is viewing an
  /// athlete, documents belong to the athlete (mirrors web +
  /// OffersListViewModel); otherwise the logged-in user's own id.
  private var userId: String? {
    familyManager.selectedAthlete?.userId ?? authManager.user?.id
  }

  func schoolName(for schoolId: String?) -> String {
    guard let id = schoolId else { return "General" }
    return schools.first { $0.id == id }?.name ?? "Unknown"
  }

  var availableSchoolsForShare: [School] {
    let sharedIds = Set(document?.sharedWithSchools ?? [])
    return schools.filter { !sharedIds.contains($0.id) }
  }

  var canSaveEdit: Bool {
    let title = editTitle.trimmingCharacters(in: .whitespaces)
    return !title.isEmpty && title.count <= 100 && (editDescription.count <= 500)
  }

  // MARK: - Init

  init(
    documentId: String,
    documentsService: (any DocumentsManaging)? = nil,
    schoolsService: (any SchoolsManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    familyManager: FamilyManager? = nil,
    cache: (any CacheManaging)? = nil
  ) {
    self.documentId = documentId
    self.documentsService = documentsService ?? DocumentsServiceImpl()
    self.schoolsService = schoolsService ?? SchoolsServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.familyManager = familyManager ?? FamilyManager.shared
    self.cache = cache
  }

  // MARK: - Load

  func loadDocument() async {
    guard authManager.user != nil else {
      error = "You must be signed in to view this document."
      return
    }

    logger.debug("Loading document: \(self.documentId)")
    isLoading = true
    error = nil
    isNotFound = false
    defer { isLoading = false }

    let cacheKey = "document:\(documentId)"
    let cacheToUse = cache ?? InMemoryCache.shared

    if let cachedDoc = await cacheToUse.get(Document.self, forKey: cacheKey) {
      document = cachedDoc
      logger.info("Loaded document from cache: \(self.documentId)")
      await fetchVersions()
      return
    }

    do {
      document = try await documentsService.fetchDocument(id: self.documentId)
      if let doc = document {
        await cacheToUse.set(doc, forKey: cacheKey, ttlSeconds: Self.documentCacheTTL)
      }
      logger.info("Loaded document: \(self.documentId)")
      await fetchVersions()
    } catch {
      logger.error("Failed to load document: \(error.localizedDescription)")
      if Self.isDocumentNotFound(error) {
        document = nil
        isNotFound = true
        self.error = nil
      } else if Self.isUnauthorized(error) {
        await handleAuthErrorIfNeeded(error)
      } else {
        self.error = "Unable to load document details. Check your connection."
      }
    }
  }

  private static func isDocumentNotFound(_ error: Error) -> Bool {
    let ns = error as NSError
    if ns.code == 404 { return true }
    let msg = error.localizedDescription.lowercased()
    return msg.contains("not found") || msg.contains("404") || msg.contains("pgrst116")
  }

  private static func isUnauthorized(_ error: Error) -> Bool {
    let ns = error as NSError
    if ns.code == 401 { return true }
    let msg = error.localizedDescription.lowercased()
    return msg.contains("401") || msg.contains("unauthorized") || msg.contains("jwt") || msg.contains("session expired")
  }

  private func handleAuthErrorIfNeeded(_ error: Error) async {
    guard Self.isUnauthorized(error) else { return }
    logger.warning("Unauthorized error - signing out")
    do {
      try await authManager.logout()
    } catch {
      logger.error("Logout failed: \(error.localizedDescription)")
    }
    self.error = "Your session has expired. Please sign in again."
  }

  func loadSchools() async {
    guard let familyUnitId = familyManager.familyUnitId else { return }

    do {
      schools = try await schoolsService.fetchSchools(familyUnitId: familyUnitId)
    } catch {
      logger.error("Failed to load schools: \(error.localizedDescription)")
    }
  }

  private func invalidateDocumentCache() async {
    let cacheToUse = cache ?? InMemoryCache.shared
    await cacheToUse.remove(forKey: "document:\(documentId)")
  }

  // MARK: - Edit

  func openEditForm() {
    guard let doc = document else { return }
    editTitle = doc.title
    editDescription = doc.description ?? ""
    editSchoolId = doc.schoolId
    showEditSheet = true
  }

  func saveEdit() async {
    guard canSaveEdit else { return }
    isSaving = true
    defer { isSaving = false }

    let title = editTitle.trimmingCharacters(in: .whitespaces)
    let desc = editDescription.trimmingCharacters(in: .whitespaces)
    let descOpt = desc.isEmpty ? nil : desc

    do {
      document = try await documentsService.updateDocument(
        id: self.documentId,
        title: title,
        description: descOpt,
        schoolId: editSchoolId
      )
      await invalidateDocumentCache()
      showEditSheet = false
      logger.info("Updated document: \(self.documentId)")
    } catch {
      logger.error("Failed to save: \(error.localizedDescription)")
      if Self.isUnauthorized(error) {
        await handleAuthErrorIfNeeded(error)
      } else {
        self.error = "Failed to save changes. Please try again."
      }
    }
  }

  // MARK: - Share

  func presentShareModal() {
    selectedSchoolIds = []
    showShareModal = true
  }

  func toggleSchoolSelection(_ schoolId: String) {
    if selectedSchoolIds.contains(schoolId) {
      selectedSchoolIds.remove(schoolId)
    } else {
      selectedSchoolIds.insert(schoolId)
    }
  }

  func saveShare() async {
    guard document != nil else { return }

    for schoolId in selectedSchoolIds {
      do {
        try await documentsService.shareDocument(documentId: self.documentId, schoolId: schoolId)
      } catch {
        logger.error("Failed to share: \(error.localizedDescription)")
        if Self.isUnauthorized(error) {
          await handleAuthErrorIfNeeded(error)
        } else {
          self.error = "Failed to share document. Check your connection."
        }
        return
      }
    }

    selectedSchoolIds = []
    showShareModal = false
    if let refreshed = try? await documentsService.fetchDocument(id: self.documentId) {
      document = refreshed
    }
    await invalidateDocumentCache()
    logger.info("Saved share for document: \(self.documentId)")
  }

  func removeShare(schoolId: String) async {
    do {
      try await documentsService.revokeShare(documentId: self.documentId, schoolId: schoolId)
      if let refreshed = try? await documentsService.fetchDocument(id: self.documentId) {
        document = refreshed
      }
      await invalidateDocumentCache()
      logger.info("Removed share for document: \(self.documentId)")
    } catch {
      logger.error("Failed to remove share: \(error.localizedDescription)")
      if Self.isUnauthorized(error) {
        await handleAuthErrorIfNeeded(error)
      } else {
        self.error = "Failed to remove school access."
      }
    }
  }

  // MARK: - Version History

  func fetchVersions() async {
    guard let doc = document else { return }

    do {
      versions = try await documentsService.fetchVersionHistory(documentId: self.documentId, document: doc)
    } catch {
      logger.error("Failed to fetch versions: \(error.localizedDescription)")
      versions = []
    }
  }

  func confirmRestore(version: DocumentVersion) {
    versionToRestore = version
    showRestoreConfirmation = true
  }

  func restoreVersion() async {
    guard let version = versionToRestore, document != nil else {
      showRestoreConfirmation = false
      versionToRestore = nil
      return
    }

    showRestoreConfirmation = false
    versionToRestore = nil

    let currentVersionId = versions.first { $0.isCurrent }?.id
    if let currentId = currentVersionId {
      do {
        try await documentsService.updateDocumentIsCurrent(id: currentId, isCurrent: false)
      } catch {
        logger.error("Failed to unmark current: \(error.localizedDescription)")
        if Self.isUnauthorized(error) {
          await handleAuthErrorIfNeeded(error)
        } else {
          self.error = "Failed to restore version. Please try again."
        }
        return
      }
    }

    do {
      try await documentsService.updateDocumentIsCurrent(id: version.id, isCurrent: true)
      if let refreshed = try? await documentsService.fetchDocument(id: self.documentId) {
        document = refreshed
      }
      await invalidateDocumentCache()
      await fetchVersions()
      logger.info("Restored version \(version.version)")
    } catch {
      logger.error("Failed to restore: \(error.localizedDescription)")
      if Self.isUnauthorized(error) {
        await handleAuthErrorIfNeeded(error)
      } else {
        self.error = "Failed to restore version. Please try again."
      }
    }
  }

  func uploadNewVersion(file: URL) async {
    guard let userId, let doc = document else { return }

    let ext = "." + file.pathExtension.lowercased()
    guard doc.type.allowedExtensions.contains(ext) else {
      error = "Invalid file type. \(doc.type.label) requires \(doc.type.allowedExtensions.joined(separator: ", "))."
      return
    }

    let maxBytes = 100 * 1024 * 1024
    if let fileSize = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, fileSize > maxBytes {
      error = "File exceeds 100MB limit."
      return
    }

    isUploadingNewVersion = true
    uploadProgress = 0
    defer {
      isUploadingNewVersion = false
      uploadProgress = 0
    }

    do {
      let data = try Data(contentsOf: file)
      let mimeType = mimeTypeForExtension(file.pathExtension)
      let newVersion = (versions.map { $0.version }.max() ?? doc.version) + 1

      uploadProgress = 0.5
      let newDoc = try await documentsService.uploadDocument(
        userId: userId,
        file: data,
        fileName: file.lastPathComponent,
        mimeType: mimeType,
        type: doc.type,
        title: doc.title,
        description: doc.description,
        schoolId: doc.schoolId,
        version: newVersion
      )
      uploadProgress = 1
      document = newDoc
      await invalidateDocumentCache()
      await fetchVersions()
      logger.info("Uploaded new version for document: \(self.documentId)")
    } catch {
      logger.error("Upload failed: \(error.localizedDescription)")
      if Self.isUnauthorized(error) {
        await handleAuthErrorIfNeeded(error)
      } else {
        self.error = "Upload failed: \(error.localizedDescription)"
      }
    }
  }

  private func mimeTypeForExtension(_ ext: String) -> String {
    switch ext.lowercased() {
    case "pdf": return "application/pdf"
    case "mp4": return "video/mp4"
    case "mov": return "video/quicktime"
    case "avi": return "video/x-msvideo"
    case "txt": return "text/plain"
    case "doc": return "application/msword"
    case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    case "csv": return "text/csv"
    case "xls": return "application/vnd.ms-excel"
    case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    default: return "application/octet-stream"
    }
  }

  // MARK: - Delete

  func confirmDelete() {
    showDeleteConfirmation = true
  }

  func deleteDocument() async {
    guard let userId else { return }
    let idToDelete = document?.id ?? self.documentId

    isDeleting = true
    defer { isDeleting = false }

    do {
      try await documentsService.deleteDocument(id: idToDelete, userId: userId)
      await invalidateDocumentCache()
      shouldDismiss = true
      logger.info("Deleted document: \(self.documentId)")
    } catch {
      logger.error("Delete failed: \(error.localizedDescription)")
      if Self.isUnauthorized(error) {
        await handleAuthErrorIfNeeded(error)
      } else {
        self.error = "Failed to delete document. Please try again."
      }
    }
  }

  // MARK: - Retry

  func clearError() {
    error = nil
  }


}
