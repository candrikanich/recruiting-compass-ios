import Foundation
import Observation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "DocumentsListViewModel"
)

private let documentsViewModeKey = "documentsViewMode"
private let documentsSortByKey = "documentsSortBy"

// MARK: - DocumentSortOption

enum DocumentSortOption: String, CaseIterable {
  case newest = "newest"
  case oldest = "oldest"
  case name = "name"
  case type = "type"
  case shared = "shared"

  var label: String {
    switch self {
    case .newest: return "Newest First"
    case .oldest: return "Oldest First"
    case .name: return "Name (A-Z)"
    case .type: return "Type"
    case .shared: return "Most Shared"
    }
  }
}

// MARK: - DocumentViewMode

enum DocumentViewMode: String, CaseIterable {
  case grid = "grid"
  case list = "list"
}

// MARK: - DocumentsListViewModel

@Observable
@MainActor
final class DocumentsListViewModel {

  nonisolated deinit {}

  // MARK: - State

  var documents: [Document] = [] {
    didSet { recomputeDerivedDocuments() }
  }
  var schools: [School] = []
  var isLoading = false
  var errorMessage: String?

  /// Drives the error alert directly, without a view-local Binding(get:set:) wrapper.
  var isShowingErrorAlert: Bool {
    get { errorMessage != nil }
    set { if !newValue { errorMessage = nil } }
  }
  var isUploadFormPresented = false
  var isFilterSheetPresented = false
  var uploadProgress: Double = 0
  var documentToView: Document?

  var searchQuery = "" {
    didSet { recomputeDerivedDocuments() }
  }
  var selectedTypes: Set<DocumentType> = [] {
    didSet { recomputeDerivedDocuments() }
  }
  var selectedSchoolId: String? {
    didSet { recomputeDerivedDocuments() }
  }
  var showSharedOnly = false {
    didSet { recomputeDerivedDocuments() }
  }

  private var _sortBy: DocumentSortOption
  var sortBy: DocumentSortOption {
    get { _sortBy }
    set {
      _sortBy = newValue
      UserDefaults.standard.set(newValue.rawValue, forKey: documentsSortByKey)
      recomputeDerivedDocuments()
    }
  }

  private var _viewMode: DocumentViewMode
  var viewMode: DocumentViewMode {
    get { _viewMode }
    set {
      _viewMode = newValue
      UserDefaults.standard.set(newValue.rawValue, forKey: documentsViewModeKey)
    }
  }

  // Upload form state
  var uploadType: DocumentType?
  var uploadTitle = ""
  var uploadDescription = ""
  var uploadSchoolId: String?
  var uploadVersion = 1
  var selectedFileURL: URL?
  var selectedFileName: String?
  var isUploading = false
  var uploadError: String?

  // MARK: - Computed

  /// Cached derived lists — recomputed via `recomputeDerivedDocuments()` whenever
  /// `documents`, `searchQuery`, `selectedTypes`, `selectedSchoolId`, `showSharedOnly`,
  /// or `sortBy` change. Do not compute these inline elsewhere; they would go
  /// stale silently. `filteredDocuments` and `sortedDocuments` were previously
  /// computed properties independently re-derived on every read (worst case:
  /// read 4x per view body eval per the audit plan).
  private(set) var filteredDocuments: [Document] = []
  private(set) var sortedDocuments: [Document] = []

  private func recomputeDerivedDocuments() {
    var result = documents

    if !searchQuery.isEmpty {
      let query = searchQuery
      result = result.filter {
        $0.title.localizedStandardContains(query)
        || ($0.description?.localizedStandardContains(query) ?? false)
      }
    }

    if !selectedTypes.isEmpty {
      result = result.filter { selectedTypes.contains($0.type) }
    }

    if let schoolId = selectedSchoolId {
      if schoolId == "general" {
        result = result.filter { $0.schoolId == nil }
      } else {
        result = result.filter { $0.schoolId == schoolId }
      }
    }

    if showSharedOnly {
      result = result.filter { $0.isShared }
    }

    filteredDocuments = result

    sortedDocuments = result.sorted { a, b in
      switch sortBy {
      case .newest:
        return (a.createdAt ?? "") > (b.createdAt ?? "")
      case .oldest:
        return (a.createdAt ?? "") < (b.createdAt ?? "")
      case .name:
        return a.title.localizedCompare(b.title) == .orderedAscending
      case .type:
        return a.type.rawValue.localizedCompare(b.type.rawValue) == .orderedAscending
      case .shared:
        return a.sharedWithSchools.count > b.sharedWithSchools.count
      }
    }
  }

  var statistics: DocumentStatistics {
    let sharedCount = documents.filter { $0.isShared }.count
    let typeCounts = Dictionary(grouping: documents, by: { $0.type })
      .mapValues { $0.count }
    let mostCommon = typeCounts.max(by: { $0.value < $1.value })
    let mostCommonLabel = mostCommon.map { $0.key.label } ?? "N/A"
    return DocumentStatistics(
      total: documents.count,
      shared: sharedCount,
      mostCommonType: mostCommonLabel,
      totalStorageMB: 0  // Phase 5 placeholder
    )
  }

  var hasActiveFilters: Bool {
    !searchQuery.isEmpty || !selectedTypes.isEmpty || selectedSchoolId != nil || showSharedOnly
  }

  var activeFilterCount: Int {
    var count = 0
    if !searchQuery.isEmpty { count += 1 }
    if !selectedTypes.isEmpty { count += selectedTypes.count }
    if selectedSchoolId != nil { count += 1 }
    if showSharedOnly { count += 1 }
    return count
  }

  // MARK: - Dependencies

  private let documentsService: any DocumentsManaging
  private let schoolsService: any SchoolsManaging
  private let authManager: any AuthManaging
  private let familyManager: FamilyManager

  /// The user whose documents we read/write. When a parent is viewing an
  /// athlete, documents belong to the athlete (mirrors web +
  /// OffersListViewModel); otherwise the logged-in user's own id.
  private var targetUserId: String? {
    familyManager.selectedAthlete?.userId ?? authManager.user?.id
  }

  // MARK: - Init

  private let cache: (any CacheManaging)?

  /// TTL for cached documents list (seconds).
  private static let documentsListCacheTTL: TimeInterval = 60

  init(
    documentsService: (any DocumentsManaging)? = nil,
    schoolsService: (any SchoolsManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    familyManager: FamilyManager? = nil,
    cache: (any CacheManaging)? = nil
  ) {
    self.documentsService = documentsService ?? DocumentsServiceImpl()
    self.schoolsService = schoolsService ?? SchoolsServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.familyManager = familyManager ?? FamilyManager.shared
    self.cache = cache
    let sortRaw = UserDefaults.standard.string(forKey: documentsSortByKey)
    self._sortBy = DocumentSortOption(rawValue: sortRaw ?? "") ?? .newest
    let viewRaw = UserDefaults.standard.string(forKey: documentsViewModeKey)
    self._viewMode = DocumentViewMode(rawValue: viewRaw ?? "") ?? .grid
  }

  /// Invalidates the cached documents list so the next `loadDocuments()`
  /// refetches. Call after any mutation (upload, delete). `DocumentDetailViewModel`
  /// invalidates the same key (via `ListCacheKeys.documents`) after edit/share/delete.
  private func invalidateDocumentsListCache() async {
    guard let userId = targetUserId else { return }
    await (cache ?? InMemoryCache.shared).remove(forKey: ListCacheKeys.documents(userId: userId))
  }

  // MARK: - Load

  func loadDocuments() async {
    guard let userId = targetUserId else {
      logger.warning("No userId for documents")
      return
    }

    logger.debug("Loading documents for user: \(userId)")
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    let cacheKey = ListCacheKeys.documents(userId: userId)
    let cacheToUse = cache ?? InMemoryCache.shared

    do {
      if let cached = await cacheToUse.get([Document].self, forKey: cacheKey) {
        documents = cached
        logger.info("Loaded \(self.documents.count) documents from cache")
      } else {
        let fetched = try await documentsService.fetchDocuments(userId: userId)
        documents = fetched
        await cacheToUse.set(fetched, forKey: cacheKey, ttlSeconds: Self.documentsListCacheTTL)
        logger.info("Loaded \(self.documents.count) documents")
      }
    } catch {
      logger.error("Failed to load documents: \(error.localizedDescription)")
      self.errorMessage = "Unable to load documents. Check your connection."
    }
  }

  func loadSchools() async {
    guard let familyUnitId = familyManager.familyUnitId else { return }

    do {
      schools = try await schoolsService.fetchSchools(familyUnitId: familyUnitId)
    } catch {
      logger.error("Failed to load schools: \(error.localizedDescription)")
    }
  }

  // MARK: - Upload Form

  func presentUploadForm() {
    resetUploadForm()
    isUploadFormPresented = true
  }

  func dismissUploadForm() {
    isUploadFormPresented = false
    resetUploadForm()
  }

  func resetUploadForm() {
    uploadType = nil
    uploadTitle = ""
    uploadDescription = ""
    uploadSchoolId = nil
    uploadVersion = 1
    selectedFileURL = nil
    selectedFileName = nil
    uploadError = nil
    uploadProgress = 0
  }

  func setSelectedFile(_ url: URL) {
    selectedFileURL = url
    selectedFileName = url.lastPathComponent
  }

  func uploadDocument() async {
    guard let userId = targetUserId else { return }
    guard let type = uploadType else {
      uploadError = "Please select a document type."
      return
    }
    guard !uploadTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
      uploadError = "Please enter a title."
      return
    }
    guard let fileURL = selectedFileURL else {
      uploadError = "Please select a file."
      return
    }

    let maxBytes = 100 * 1024 * 1024  // 100MB
    if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, fileSize > maxBytes {
      uploadError = "File exceeds 100MB limit. Please compress or choose a smaller file."
      return
    }

    let ext = "." + (fileURL.pathExtension.lowercased())
    guard type.allowedExtensions.contains(ext) else {
      uploadError = "Invalid file type. \(type.label) requires \(type.allowedExtensions.joined(separator: ", "))."
      return
    }

    isUploading = true
    uploadError = nil
    defer { isUploading = false; uploadProgress = 0 }

    do {
      let data = try Data(contentsOf: fileURL)
      let mimeType = mimeTypeForExtension(fileURL.pathExtension)

      uploadProgress = 0.5  // Show progress during upload; set to 1 on success

      let doc = try await documentsService.uploadDocument(
        userId: userId,
        file: data,
        fileName: fileURL.lastPathComponent,
        mimeType: mimeType,
        type: type,
        title: uploadTitle.trimmingCharacters(in: .whitespaces),
        description: uploadDescription.isEmpty ? nil : uploadDescription,
        schoolId: uploadSchoolId,
        version: uploadVersion
      )

      uploadProgress = 1
      documents.insert(doc, at: 0)
      await invalidateDocumentsListCache()
      dismissUploadForm()
    } catch {
      logger.error("Upload failed: \(error.localizedDescription)")
      uploadError = "Upload failed. Please check your connection and try again."
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

  func deleteDocument(id: String) async {
    guard let userId = targetUserId else { return }

    do {
      try await documentsService.deleteDocument(id: id, userId: userId)
      documents.removeAll { $0.id == id }
      await invalidateDocumentsListCache()
    } catch {
      logger.error("Delete failed: \(error.localizedDescription)")
      self.errorMessage = "Failed to delete document. Please try again."
    }
  }

  // MARK: - Filters

  func clearFilters() {
    searchQuery = ""
    selectedTypes = []
    selectedSchoolId = nil
    showSharedOnly = false
  }

  func toggleType(_ type: DocumentType) {
    if selectedTypes.contains(type) {
      selectedTypes.remove(type)
    } else {
      selectedTypes.insert(type)
    }
  }

  func schoolName(for schoolId: String?) -> String {
    guard let id = schoolId else { return "General" }
    return schools.first { $0.id == id }?.name ?? "Unknown"
  }

  // MARK: - Document Viewer

  func presentViewer(for document: Document) {
    documentToView = document
  }

}
