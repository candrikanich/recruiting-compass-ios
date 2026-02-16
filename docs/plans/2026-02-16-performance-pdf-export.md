# Performance Dashboard PDF Export Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add PDF export functionality to Performance Dashboard to match web implementation spec

**Architecture:** Extend existing export system to support both CSV and PDF formats. Use PDFKit to generate formatted PDF documents containing metric summary, statistics, and history table. Refactor ExportMetricsSheet to present format selection options.

**Tech Stack:** SwiftUI, PDFKit, Swift Charts (for potential chart rendering in PDF), existing PerformanceManaging service

---

## Task 1: Create PDF Generator Utility

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Performance/Utilities/PerformancePDFGenerator.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Performance/Utilities/PerformancePDFGeneratorTests.swift`

**Step 1: Write the failing test**

Create test file with basic structure test:

```swift
import XCTest
@testable import TheRecruitingCompass

final class PerformancePDFGeneratorTests: XCTestCase {
  func testGeneratePDF_WithMetrics_ReturnsValidPDFData() {
    // Given
    let metrics = [
      PerformanceMetric(
        id: "1",
        userId: "user1",
        metricType: .velocity,
        value: 85.5,
        unit: "mph",
        recordedDate: Date(),
        eventId: nil,
        verified: false,
        notes: "Test note",
        createdAt: Date(),
        updatedAt: Date()
      )
    ]
    let generator = PerformancePDFGenerator()

    // When
    let pdfData = generator.generate(metrics: metrics, userName: "Test User")

    // Then
    XCTAssertNotNil(pdfData)
    XCTAssertGreaterThan(pdfData.count, 0)
  }

  func testGeneratePDF_WithEmptyMetrics_ReturnsValidPDFData() {
    // Given
    let generator = PerformancePDFGenerator()

    // When
    let pdfData = generator.generate(metrics: [], userName: "Test User")

    // Then
    XCTAssertNotNil(pdfData)
    XCTAssertGreaterThan(pdfData.count, 0)
  }
}
```

**Step 2: Run test to verify it fails**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/PerformancePDFGeneratorTests
```

Expected: FAIL - "Use of unresolved identifier 'PerformancePDFGenerator'"

**Step 3: Write minimal implementation**

Create `TheRecruitingCompass/TheRecruitingCompass/Features/Performance/Utilities/PerformancePDFGenerator.swift`:

```swift
import Foundation
import PDFKit
import UIKit

final class PerformancePDFGenerator {
  private let pageWidth: CGFloat = 612.0  // 8.5 inches at 72 DPI
  private let pageHeight: CGFloat = 792.0 // 11 inches at 72 DPI
  private let margin: CGFloat = 50.0

  func generate(metrics: [PerformanceMetric], userName: String?) -> Data {
    let pdfMetaData = [
      kCGPDFContextTitle: "Performance Metrics Report",
      kCGPDFContextAuthor: userName ?? "Athlete"
    ]

    let format = UIGraphicsPDFRendererFormat()
    format.documentInfo = pdfMetaData as [String: Any]

    let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
    let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

    let data = renderer.pdfData { context in
      context.beginPage()

      var currentY: CGFloat = margin

      // Title
      currentY = drawTitle(in: context.cgContext, y: currentY)

      // Metadata
      currentY = drawMetadata(in: context.cgContext, y: currentY, userName: userName)

      // Summary Stats
      currentY = drawSummaryStats(in: context.cgContext, y: currentY, metrics: metrics)

      // Metric History Table
      drawMetricHistory(in: context.cgContext, y: currentY, metrics: metrics)
    }

    return data
  }

  // MARK: - Drawing Methods

  private func drawTitle(in context: CGContext, y: CGFloat) -> CGFloat {
    let title = "Performance Metrics Report"
    let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
    let titleAttributes: [NSAttributedString.Key: Any] = [
      .font: titleFont,
      .foregroundColor: UIColor.black
    ]

    let titleSize = title.size(withAttributes: titleAttributes)
    let titleX = (pageWidth - titleSize.width) / 2

    title.draw(at: CGPoint(x: titleX, y: y), withAttributes: titleAttributes)

    return y + titleSize.height + 20
  }

  private func drawMetadata(in context: CGContext, y: CGFloat, userName: String?) -> CGFloat {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .long

    var currentY = y
    let font = UIFont.systemFont(ofSize: 12)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: UIColor.darkGray
    ]

    if let userName = userName {
      let text = "Athlete: \(userName)"
      text.draw(at: CGPoint(x: margin, y: currentY), withAttributes: attributes)
      currentY += 20
    }

    let dateText = "Generated: \(dateFormatter.string(from: Date()))"
    dateText.draw(at: CGPoint(x: margin, y: currentY), withAttributes: attributes)

    return currentY + 30
  }

  private func drawSummaryStats(in context: CGContext, y: CGFloat, metrics: [PerformanceMetric]) -> CGFloat {
    var currentY = y

    let sectionTitle = "Summary"
    let titleFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
    let titleAttributes: [NSAttributedString.Key: Any] = [
      .font: titleFont,
      .foregroundColor: UIColor.black
    ]

    sectionTitle.draw(at: CGPoint(x: margin, y: currentY), withAttributes: titleAttributes)
    currentY += 30

    let font = UIFont.systemFont(ofSize: 12)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: UIColor.black
    ]

    let totalText = "Total Metrics Logged: \(metrics.count)"
    totalText.draw(at: CGPoint(x: margin, y: currentY), withAttributes: attributes)
    currentY += 20

    let typeCount = Set(metrics.map(\.metricType)).count
    let typesText = "Unique Metric Types: \(typeCount)"
    typesText.draw(at: CGPoint(x: margin, y: currentY), withAttributes: attributes)

    return currentY + 40
  }

  private func drawMetricHistory(in context: CGContext, y: CGFloat, metrics: [PerformanceMetric]) {
    var currentY = y

    let sectionTitle = "Metric History"
    let titleFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
    let titleAttributes: [NSAttributedString.Key: Any] = [
      .font: titleFont,
      .foregroundColor: UIColor.black
    ]

    sectionTitle.draw(at: CGPoint(x: margin, y: currentY), withAttributes: titleAttributes)
    currentY += 30

    if metrics.isEmpty {
      let emptyText = "No metrics logged yet."
      let font = UIFont.systemFont(ofSize: 12)
      let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: UIColor.darkGray
      ]
      emptyText.draw(at: CGPoint(x: margin, y: currentY), withAttributes: attributes)
      return
    }

    // Draw table header
    currentY = drawTableHeader(in: context, y: currentY)

    // Draw table rows
    let sortedMetrics = metrics.sorted { $0.recordedDate > $1.recordedDate }
    for metric in sortedMetrics.prefix(50) {
      currentY = drawTableRow(in: context, y: currentY, metric: metric)

      // Check if we need a new page
      if currentY > pageHeight - margin - 20 {
        break
      }
    }
  }

  private func drawTableHeader(in context: CGContext, y: CGFloat) -> CGFloat {
    let font = UIFont.systemFont(ofSize: 10, weight: .semibold)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: UIColor.black
    ]

    let headers = ["Type", "Value", "Date", "Verified"]
    let columnWidths: [CGFloat] = [150, 100, 120, 80]
    var x = margin

    for (index, header) in headers.enumerated() {
      header.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
      x += columnWidths[index]
    }

    // Draw line under header
    context.setStrokeColor(UIColor.lightGray.cgColor)
    context.setLineWidth(0.5)
    context.move(to: CGPoint(x: margin, y: y + 15))
    context.addLine(to: CGPoint(x: pageWidth - margin, y: y + 15))
    context.strokePath()

    return y + 20
  }

  private func drawTableRow(in context: CGContext, y: CGFloat, metric: PerformanceMetric) -> CGFloat {
    let font = UIFont.systemFont(ofSize: 10)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: UIColor.black
    ]

    let columnWidths: [CGFloat] = [150, 100, 120, 80]
    var x = margin

    // Type
    metric.metricType.displayName.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
    x += columnWidths[0]

    // Value
    metric.formattedValue.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
    x += columnWidths[1]

    // Date
    metric.formattedDate.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
    x += columnWidths[2]

    // Verified
    let verifiedText = metric.verified ? "✓" : ""
    verifiedText.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)

    return y + 18
  }
}
```

**Step 4: Run test to verify it passes**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/PerformancePDFGeneratorTests
```

Expected: PASS - All tests green

**Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Performance/Utilities/PerformancePDFGenerator.swift
git add TheRecruitingCompass/TheRecruitingCompassTests/Features/Performance/Utilities/PerformancePDFGeneratorTests.swift
git commit -m "feat(performance): add PDF generator utility"
```

---

## Task 2: Add PDF Generation to ViewModel

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Performance/ViewModels/PerformanceDashboardViewModel.swift:249-257`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Performance/ViewModels/PerformanceDashboardViewModelTests.swift`

**Step 1: Write the failing test**

Add test to `PerformanceDashboardViewModelTests.swift`:

```swift
@MainActor
func testGeneratePDF_ReturnsValidPDFData() async {
  // Given
  let mockService = MockPerformanceService()
  let mockAuth = MockAuthManager()
  mockAuth.mockUser = User(
    id: "user1",
    email: "test@example.com",
    role: .athlete,
    createdAt: Date(),
    updatedAt: Date()
  )

  let viewModel = PerformanceDashboardViewModel(
    performanceService: mockService,
    authManager: mockAuth
  )

  mockService.mockMetrics = [
    PerformanceMetric(
      id: "1",
      userId: "user1",
      metricType: .velocity,
      value: 85.5,
      unit: "mph",
      recordedDate: Date(),
      eventId: nil,
      verified: false,
      notes: nil,
      createdAt: Date(),
      updatedAt: Date()
    )
  ]

  await viewModel.loadMetrics()

  // When
  let pdfData = viewModel.generatePDF()

  // Then
  XCTAssertGreaterThan(pdfData.count, 0)
}
```

**Step 2: Run test to verify it fails**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/PerformanceDashboardViewModelTests/testGeneratePDF_ReturnsValidPDFData
```

Expected: FAIL - "Value of type 'PerformanceDashboardViewModel' has no member 'generatePDF'"

**Step 3: Write minimal implementation**

Add to `PerformanceDashboardViewModel.swift` after `generateCSV()`:

```swift
func generatePDF() -> Data {
  let generator = PerformancePDFGenerator()
  let userName = authManager.user?.email
  return generator.generate(metrics: sortedMetrics, userName: userName)
}
```

**Step 4: Run test to verify it passes**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/PerformanceDashboardViewModelTests/testGeneratePDF_ReturnsValidPDFData
```

Expected: PASS

**Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Performance/ViewModels/PerformanceDashboardViewModel.swift
git add TheRecruitingCompass/TheRecruitingCompassTests/Features/Performance/ViewModels/PerformanceDashboardViewModelTests.swift
git commit -m "feat(performance): add PDF generation method to ViewModel"
```

---

## Task 3: Create Export Format Selection Component

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Performance/Components/ExportFormatSheet.swift`
- Test: Manual UI testing (component test in preview)

**Step 1: Create component file**

Create `ExportFormatSheet.swift`:

```swift
import SwiftUI

enum ExportFormat: String, CaseIterable, Identifiable {
  case csv = "CSV"
  case pdf = "PDF"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .csv: return "doc.text"
    case .pdf: return "doc.richtext"
    }
  }

  var description: String {
    switch self {
    case .csv: return "Spreadsheet format, compatible with Excel"
    case .pdf: return "Formatted document with charts and tables"
    }
  }
}

struct ExportFormatSheet: View {
  let csvData: Data
  let pdfData: Data
  @Environment(\.dismiss) private var dismiss
  @State private var selectedFormat: ExportFormat = .csv
  @State private var showShareSheet = false

  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        // Icon
        Image(systemName: "square.and.arrow.up")
          .font(.system(size: 48))
          .foregroundStyle(Color.accentBlue)
          .padding(.top)

        // Title
        Text("Export Metrics")
          .font(.title2)
          .fontWeight(.bold)

        // Format Selection
        VStack(alignment: .leading, spacing: 12) {
          Text("Select Format")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)

          ForEach(ExportFormat.allCases) { format in
            FormatOptionCard(
              format: format,
              isSelected: selectedFormat == format,
              onTap: { selectedFormat = format }
            )
          }
        }
        .padding(.horizontal)

        Spacer()

        // Export Button
        Button {
          showShareSheet = true
        } label: {
          Label("Export \(selectedFormat.rawValue)", systemImage: "square.and.arrow.up")
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
        .padding(.bottom)
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      .sheet(isPresented: $showShareSheet) {
        ShareSheetView(data: currentFormatData, filename: currentFilename)
      }
    }
  }

  private var currentFormatData: Data {
    selectedFormat == .csv ? csvData : pdfData
  }

  private var currentFilename: String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let dateString = dateFormatter.string(from: Date())
    return "performance_metrics_\(dateString).\(selectedFormat.rawValue.lowercased())"
  }
}

struct FormatOptionCard: View {
  let format: ExportFormat
  let isSelected: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 16) {
        Image(systemName: format.icon)
          .font(.title2)
          .foregroundStyle(isSelected ? Color.accentBlue : .secondary)
          .frame(width: 40)

        VStack(alignment: .leading, spacing: 4) {
          Text(format.rawValue)
            .font(.headline)
            .foregroundStyle(.primary)

          Text(format.description)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.accentBlue)
        }
      }
      .padding()
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(isSelected ? Color.accentBlue.opacity(0.1) : Color(.systemGray6))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(isSelected ? Color.accentBlue : Color.clear, lineWidth: 2)
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(format.rawValue) format, \(format.description)")
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }
}

struct ShareSheetView: View {
  let data: Data
  let filename: String
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    if let url = saveToTempFile() {
      ShareLink(item: url) {
        Label("Share \(filename)", systemImage: "square.and.arrow.up")
      }
      .onAppear {
        // Auto-dismiss after sharing starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          dismiss()
        }
      }
    } else {
      ContentUnavailableView(
        "Export Failed",
        systemImage: "exclamationmark.triangle",
        description: Text("Unable to prepare file for sharing")
      )
    }
  }

  private func saveToTempFile() -> URL? {
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    do {
      try data.write(to: tempURL)
      return tempURL
    } catch {
      return nil
    }
  }
}

#Preview {
  ExportFormatSheet(
    csvData: "test,data\n1,2".data(using: .utf8)!,
    pdfData: Data()
  )
}
```

**Step 2: Test in preview**

```bash
# Open in Xcode and view preview
open TheRecruitingCompass/TheRecruitingCompass.xcodeproj
# Navigate to ExportFormatSheet.swift and verify preview renders
```

Expected: Preview shows format selection UI

**Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Performance/Components/ExportFormatSheet.swift
git commit -m "feat(performance): add export format selection sheet component"
```

---

## Task 4: Integrate Export Format Sheet into View

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Performance/Views/PerformanceDashboardView.swift:78-81,251-293`

**Step 1: Remove old ExportMetricsSheet**

Delete lines 251-293 (the old `ExportMetricsSheet` struct and `SuccessToast` struct - keep SuccessToast)

**Step 2: Update sheet presentation**

Replace the export sheet section (lines 78-81) with:

```swift
.sheet(isPresented: $viewModel.showExportSheet) {
  ExportFormatSheet(
    csvData: viewModel.generateCSV().data(using: .utf8) ?? Data(),
    pdfData: viewModel.generatePDF()
  )
  .presentationDetents([.medium])
}
```

**Step 3: Test manually**

```bash
cd TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: Build succeeds

**Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Performance/Views/PerformanceDashboardView.swift
git commit -m "feat(performance): integrate PDF export into UI"
```

---

## Task 5: Add E2E Test for PDF Export

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompassUITests/Features/Performance/PerformanceDashboardE2ETests.swift`

**Step 1: Add export flow test**

Add to test file:

```swift
@MainActor
func testExportPDFFlow() throws {
  let app = XCUIApplication()
  app.launch()

  // Navigate to Performance tab
  app.tabBars.buttons["Performance"].tap()

  // Wait for metrics to load (or log a metric first)
  sleep(2)

  // Tap Export button
  app.navigationBars.buttons["Export"].tap()

  // Verify export sheet appears
  XCTAssertTrue(app.staticTexts["Export Metrics"].waitForExistence(timeout: 2))

  // Select PDF format
  app.buttons.matching(identifier: "PDF format").element.tap()

  // Tap Export PDF button
  app.buttons["Export PDF"].tap()

  // Verify share sheet appears (system sheet - hard to test precisely)
  // Just verify we don't crash
  sleep(1)
}
```

**Step 2: Run test**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassUITests/PerformanceDashboardE2ETests/testExportPDFFlow
```

Expected: PASS (or manual verification)

**Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompassUITests/Features/Performance/PerformanceDashboardE2ETests.swift
git commit -m "test(performance): add E2E test for PDF export flow"
```

---

## Task 6: Update Documentation

**Files:**
- Modify: `docs/ACCESSIBILITY_AUDIT.md` (if export sheet changes affect accessibility)
- Create: `docs/PERFORMANCE_EXPORT_GUIDE.md`

**Step 1: Create export guide**

Create `docs/PERFORMANCE_EXPORT_GUIDE.md`:

```markdown
# Performance Metrics Export Guide

## Overview

The Performance Dashboard supports exporting metrics in two formats:
- **CSV**: Spreadsheet format compatible with Excel, Numbers, Google Sheets
- **PDF**: Formatted document with summary statistics and metric history

## Export Flow

1. Navigate to Performance tab
2. Tap "Export" button in navigation bar
3. Select desired format (CSV or PDF)
4. Tap "Export [FORMAT]" button
5. Use system share sheet to save or share

## CSV Format

Columns:
- Metric Type
- Value
- Unit
- Date
- Verified
- Notes

## PDF Format

Sections:
- Title: "Performance Metrics Report"
- Metadata: Athlete name, generation date
- Summary: Total metrics, unique types
- Metric History: Table of all metrics (sorted newest first, max 50 entries)

## Technical Details

**PDF Generation:**
- Uses PDFKit and UIGraphicsRenderer
- Page size: 8.5" x 11" (US Letter)
- Font: System font (10-24pt)
- Maximum 50 metrics per PDF (to prevent pagination complexity)

**CSV Generation:**
- UTF-8 encoding
- Commas in notes replaced with semicolons
- Sorted newest first

## Implementation Files

- `PerformancePDFGenerator.swift` - PDF generation logic
- `ExportFormatSheet.swift` - Format selection UI
- `PerformanceDashboardViewModel.swift` - generateCSV(), generatePDF()
```

**Step 2: Commit**

```bash
git add docs/PERFORMANCE_EXPORT_GUIDE.md
git commit -m "docs(performance): add export functionality guide"
```

---

## Task 7: Run Full Test Suite

**Step 1: Run all tests**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: All tests PASS

**Step 2: Verify build**

```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: Build succeeds with no warnings

**Step 3: Manual smoke test**

- Launch app in simulator
- Navigate to Performance tab
- Log a metric
- Export as CSV - verify file shares
- Export as PDF - verify file shares and opens correctly
- Verify PDF contains metric data

---

## Verification Checklist

Before marking complete:

- [ ] All unit tests pass
- [ ] All E2E tests pass
- [ ] Build succeeds with no warnings
- [ ] PDF export generates valid PDF files
- [ ] CSV export still works as before
- [ ] Export sheet shows both format options
- [ ] Accessibility labels present on new UI
- [ ] Documentation updated
- [ ] Code follows established patterns (MVVM, @Observable, protocol services)

---

## Rollback Plan

If critical issues found:

```bash
git revert HEAD~7..HEAD
git push origin main
```

Each task is a separate commit, allowing granular rollback if needed.
