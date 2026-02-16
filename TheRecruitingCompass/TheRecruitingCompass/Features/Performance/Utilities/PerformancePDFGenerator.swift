import Foundation
import UIKit
import PDFKit

final class PerformancePDFGenerator {
  private let pageWidth: CGFloat = 612.0  // 8.5 inches at 72 DPI
  private let pageHeight: CGFloat = 792.0 // 11 inches at 72 DPI
  private let margin: CGFloat = 50.0

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.locale = Locale(identifier: "en_US")
    return formatter
  }()

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
      currentY = drawTitle(y: currentY)

      // Metadata
      currentY = drawMetadata(y: currentY, userName: userName)

      // Summary Stats
      currentY = drawSummaryStats(y: currentY, metrics: metrics)

      // Metric History Table
      drawMetricHistory(in: context.cgContext, y: currentY, metrics: metrics)
    }

    return data
  }

  // MARK: - Drawing Methods

  private func drawTitle(y: CGFloat) -> CGFloat {
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

  private func drawMetadata(y: CGFloat, userName: String?) -> CGFloat {
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

    let dateText = "Generated: \(Self.dateFormatter.string(from: Date()))"
    dateText.draw(at: CGPoint(x: margin, y: currentY), withAttributes: attributes)

    return currentY + 30
  }

  private func drawSummaryStats(y: CGFloat, metrics: [PerformanceMetric]) -> CGFloat {
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
    let maxMetrics = min(sortedMetrics.count, 50)
    var drawnCount = 0

    for metric in sortedMetrics.prefix(maxMetrics) {
      // Check if we have room for another row + potential truncation message
      if currentY > pageHeight - margin - 40 {
        break
      }

      currentY = drawTableRow(in: context, y: currentY, metric: metric)
      drawnCount += 1
    }

    // Add truncation indicator if we didn't draw all metrics
    let remainingCount = maxMetrics - drawnCount
    if remainingCount > 0 {
      currentY += 10
      let truncationText = "... and \(remainingCount) more metric\(remainingCount == 1 ? "" : "s")"
      let font = UIFont.systemFont(ofSize: 10, weight: .medium)
      let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: UIColor.darkGray
      ]
      truncationText.draw(at: CGPoint(x: margin, y: currentY), withAttributes: attributes)
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
