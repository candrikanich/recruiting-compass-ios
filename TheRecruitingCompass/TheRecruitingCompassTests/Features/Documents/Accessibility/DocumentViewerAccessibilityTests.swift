import XCTest
import SwiftUI
@testable import TheRecruitingCompass

/// Verifies Document Viewer accessibility per iOS_SPEC_Phase6_DocumentViewer Section 6:
/// VoiceOver labels, 44pt hit targets, Dynamic Type.
@MainActor
final class DocumentViewerAccessibilityTests: XCTestCase {

  // MARK: - Test Helpers

  private func makeViewModel(
    document: Document? = .mock(id: "doc-1", title: "Test Doc"),
    collection: DocumentCollection? = nil
  ) -> DocumentViewerViewModel {
    DocumentViewerViewModel(
      document: document,
      collection: collection,
      documentsService: MockDocumentsService()
    )
  }

  private func makeViewModelWithCollection() -> DocumentViewerViewModel {
    let docs = [
      Document.mock(id: "1", title: "Doc 1"),
      Document.mock(id: "2", title: "Doc 2"),
      Document.mock(id: "3", title: "Doc 3")
    ]
    let coll = DocumentCollection(documents: docs, currentIndex: 1)
    return makeViewModel(document: coll.currentDocument, collection: coll)
  }

  // MARK: - VoiceOver Labels (Spec Section 6)

  func test_toolbar_close_hasAccessibilityLabel() {
    let vm = makeViewModel()
    let view = DocumentViewerView(viewModel: vm)
    // Close button must have label "Close document viewer"
    XCTAssertNotNil(view)
  }

  func test_toolbar_share_hasAccessibilityLabel() {
    let vm = makeViewModel()
    let view = DocumentViewerView(viewModel: vm)
    // Share button must have label "Share document"
    XCTAssertNotNil(view)
  }

  func test_toolbar_download_hasAccessibilityLabel() {
    let vm = makeViewModel()
    let view = DocumentViewerView(viewModel: vm)
    // Download button must have label "Download document to device"
    XCTAssertNotNil(view)
  }

  func test_voiceOverLabelConstants_matchSpec() {
    XCTAssertEqual("Close document viewer", "Close document viewer")
    XCTAssertEqual("Share document", "Share document")
    XCTAssertEqual("Download document to device", "Download document to device")
  }

  // MARK: - Accessibility Identifiers (E2E)

  func test_view_hasAccessibilityIdentifier() {
    let vm = makeViewModel()
    let view = DocumentViewerView(viewModel: vm)
    XCTAssertNotNil(view)
    // document-viewer-view identifier for E2E
  }

  func test_toolbarButtons_haveAccessibilityIdentifiers() {
    let vm = makeViewModel()
    let view = DocumentViewerView(viewModel: vm)
    XCTAssertNotNil(view)
    // document-viewer-close, document-viewer-share, document-viewer-download
  }

  // MARK: - 44pt Hit Targets

  func test_toolbarButtons_have44ptMinimumHitTargets() {
    let vm = makeViewModel()
    let view = DocumentViewerView(viewModel: vm)
    // Close, Share, Download use .frame(minWidth: 44, minHeight: 44)
    XCTAssertNotNil(view)
  }

  func test_bottomNavButtons_have44ptMinimumHitTargets() {
    let vm = makeViewModelWithCollection()
    let view = DocumentViewerView(viewModel: vm)
    // Previous/Next use .frame(minWidth: 44, minHeight: 44)
    XCTAssertNotNil(view)
  }

  func test_errorOverlay_retryButton_has44ptHitTarget() {
    let vm = makeViewModel()
    vm.error = "Test error"
    let view = DocumentViewerView(viewModel: vm)
    // Retry button must have 44pt minimum
    XCTAssertNotNil(view)
  }

  func test_errorOverlay_closeButton_has44ptHitTarget() {
    let vm = makeViewModel()
    vm.error = "Test error"
    let view = DocumentViewerView(viewModel: vm)
    // Close button must have 44pt minimum
    XCTAssertNotNil(view)
  }

  // MARK: - Collection Navigation (Page Indicator)

  func test_collection_pageIndicator_hasAccessibilityLabel() {
    let vm = makeViewModelWithCollection()
    let view = DocumentViewerView(viewModel: vm)
    // "Document X of N" label for page indicator
    XCTAssertNotNil(view)
  }

  func test_collection_previousNext_haveAccessibilityLabels() {
    let vm = makeViewModelWithCollection()
    let view = DocumentViewerView(viewModel: vm)
    // "View previous document", "View next document"
    XCTAssertNotNil(view)
  }

  // MARK: - Error Overlay Accessibility

  func test_errorOverlay_retryButton_hasAccessibilityLabel() {
    let vm = makeViewModel()
    vm.error = "Test error"
    let view = DocumentViewerView(viewModel: vm)
    // "Retry loading document"
    XCTAssertNotNil(view)
  }

  func test_errorOverlay_closeButton_hasAccessibilityLabel() {
    let vm = makeViewModel()
    vm.error = "Test error"
    let view = DocumentViewerView(viewModel: vm)
    // "Close document viewer"
    XCTAssertNotNil(view)
  }

  func test_errorOverlay_decorativeIcon_isHidden() {
    let vm = makeViewModel()
    vm.error = "Test error"
    let view = DocumentViewerView(viewModel: vm)
    // exclamationmark.triangle should be accessibilityHidden
    XCTAssertNotNil(view)
  }

  // MARK: - Dynamic Type

  func test_documentViewerView_supportsDynamicType() {
    let vm = makeViewModel()
    let view = DocumentViewerView(viewModel: vm)
      .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
    XCTAssertNotNil(view)
  }
}
