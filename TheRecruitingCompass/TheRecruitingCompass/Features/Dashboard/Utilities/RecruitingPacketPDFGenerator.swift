import Foundation
import UIKit
import PDFKit

/// Renders a `RecruitingPacketData` into a multi-section PDF (US Letter). Models the existing
/// `PerformancePDFGenerator` pattern: `UIGraphicsPDFRenderer`, drawn on the main actor
/// (`UIGraphicsPDFRenderer` must run on the main actor — drawing off-main crashes under test).
final class RecruitingPacketPDFGenerator {

  private let pageWidth: CGFloat = 612.0   // 8.5in @72dpi
  private let pageHeight: CGFloat = 792.0  // 11in @72dpi
  private let margin: CGFloat = 50.0

  private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.locale = Locale(identifier: "en_US")
    return formatter
  }()

  private let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .short
    formatter.locale = Locale(identifier: "en_US")
    return formatter
  }()

  @MainActor
  func generate(data: RecruitingPacketData, photo: UIImage?) -> Data {
    let name = data.athlete.fullName ?? "Athlete"
    let pdfMetaData = [
      kCGPDFContextTitle: "Recruiting Packet - \(name)",
      kCGPDFContextAuthor: name
    ]

    let format = UIGraphicsPDFRendererFormat()
    format.documentInfo = pdfMetaData as [String: Any]

    let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
    let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

    return renderer.pdfData { [self] context in
      context.beginPage()
      var y = margin
      y = drawCover(y: y, athlete: data.athlete, photo: photo)
      y = drawProfile(in: context, y: y, athlete: data.athlete)
      y = drawActivity(in: context, y: y, activity: data.activity)
      drawSchools(in: context, y: y, tiers: data.tiers, startNewPageIfNeeded: true)
      drawFooter(context: context)
    }
  }

  // MARK: - Cover

  private func drawCover(y: CGFloat, athlete: RecruitingPacketData.Athlete, photo: UIImage?) -> CGFloat {
    var currentY = y

    if let photo, let cgContext = UIGraphicsGetCurrentContext() {
      let side: CGFloat = 90
      let rect = CGRect(x: (pageWidth - side) / 2, y: currentY, width: side, height: side)
      // Clip to a circle only while drawing the photo, then restore so it never affects later text.
      cgContext.saveGState()
      UIBezierPath(ovalIn: rect).addClip()
      photo.draw(in: rect)
      cgContext.restoreGState()
      currentY += side + 16
    }

    let name = athlete.fullName ?? "Athlete Name"
    currentY = drawCentered(name, y: currentY, font: .systemFont(ofSize: 26, weight: .bold), spacingAfter: 8)

    if let position = athlete.position, !position.isEmpty {
      currentY = drawCentered(position, y: currentY, font: .systemFont(ofSize: 14, weight: .medium),
                              color: .darkGray, spacingAfter: 6)
    }

    let schoolLine = coverSchoolLine(athlete)
    if !schoolLine.isEmpty {
      currentY = drawCentered(schoolLine, y: currentY, font: .systemFont(ofSize: 12),
                              color: .darkGray, spacingAfter: 6)
    }

    let generated = "Generated on \(dateFormatter.string(from: .now))"
    currentY = drawCentered(generated, y: currentY, font: .systemFont(ofSize: 10),
                            color: .gray, spacingAfter: 24)
    return currentY
  }

  private func coverSchoolLine(_ athlete: RecruitingPacketData.Athlete) -> String {
    var parts: [String] = []
    if let school = athlete.schoolName, !school.isEmpty { parts.append(school) }
    if let year = athlete.graduationYear { parts.append("Class of \(year)") }
    return parts.joined(separator: " • ")
  }

  // MARK: - Athlete Profile

  private func drawProfile(in context: UIGraphicsPDFRendererContext, y: CGFloat,
                           athlete: RecruitingPacketData.Athlete) -> CGFloat {
    var currentY = drawSectionTitle("Athlete Profile", y: y)

    let stats: [(String, String)] = [
      ("Height", athlete.height ?? "—"),
      ("Weight", athlete.weight ?? "—"),
      ("Bats/Throws", athlete.batsThrows ?? "—"),
      ("Position", athlete.position ?? "—")
    ]
    currentY = drawStatRow(stats, y: currentY)

    // Contact Information
    currentY = drawSubTitle("Contact Information", y: currentY)
    currentY = drawLabelValue("Email", athlete.email ?? "Not provided", y: currentY)
    currentY = drawLabelValue("Phone", athlete.phone ?? "Available upon request", y: currentY)
    currentY += 8

    // Academic Information (only when any present)
    if athlete.gpa != nil || athlete.satScore != nil || athlete.actScore != nil || !athlete.coreCourses.isEmpty {
      currentY = drawSubTitle("Academic Information", y: currentY)
      if let gpa = athlete.gpa {
        currentY = drawLabelValue("GPA", String(format: "%.2f", gpa), y: currentY)
      }
      if let sat = athlete.satScore {
        currentY = drawLabelValue("SAT", "\(sat)", y: currentY)
      }
      if let act = athlete.actScore {
        currentY = drawLabelValue("ACT", "\(act)", y: currentY)
      }
      if !athlete.coreCourses.isEmpty {
        currentY = drawLabelValue("Core Courses", athlete.coreCourses.joined(separator: ", "), y: currentY)
      }
      currentY += 8
    }

    // Video Links
    if !athlete.videoLinks.isEmpty {
      currentY = drawSubTitle("Video Links", y: currentY)
      for link in athlete.videoLinks {
        currentY = drawLabelValue(link.label, link.url, y: currentY)
      }
      currentY += 8
    }

    // Social Media
    if !athlete.socialMedia.isEmpty {
      currentY = drawSubTitle("Social Media", y: currentY)
      for social in athlete.socialMedia {
        currentY = drawLabelValue(social.platform, social.handle, y: currentY)
      }
      currentY += 8
    }

    return currentY
  }

  // MARK: - Activity Summary

  private func drawActivity(in context: UIGraphicsPDFRendererContext, y: CGFloat,
                            activity: RecruitingPacketData.ActivitySummary) -> CGFloat {
    var currentY = ensureRoom(in: context, y: y, needed: 160)
    currentY = drawSubTitle("Activity Summary", y: currentY)

    let recent = activity.recentContact.map { dateFormatter.string(from: $0) } ?? "N/A"
    let summary: [(String, String)] = [
      ("Total Schools", "\(activity.totalSchools)"),
      ("Total Interactions", "\(activity.totalInteractions)"),
      ("Recent Contact", recent)
    ]
    currentY = drawStatRow(summary, y: currentY)

    currentY = drawSubTitle("Interaction Breakdown", y: currentY)
    let breakdown: [(String, String)] = [
      ("Emails", "\(activity.emails)"),
      ("Calls", "\(activity.calls)"),
      ("Camps", "\(activity.camps)"),
      ("Visits", "\(activity.visits)"),
      ("Other", "\(activity.other)")
    ]
    for (label, value) in breakdown {
      currentY = drawLabelValue(label, value, y: currentY)
    }
    return currentY + 8
  }

  // MARK: - Schools

  private func drawSchools(in context: UIGraphicsPDFRendererContext, y: CGFloat,
                           tiers: RecruitingPacketData.SchoolTiers, startNewPageIfNeeded: Bool) {
    var currentY = ensureRoom(in: context, y: y, needed: 120)
    currentY = drawSectionTitle("Schools of Interest", y: currentY)

    currentY = drawTier(in: context, title: "Priority A Schools", rows: tiers.tierA, y: currentY)
    currentY = drawTier(in: context, title: "Priority B Schools", rows: tiers.tierB, y: currentY)
    _ = drawTier(in: context, title: "Priority C Schools", rows: tiers.tierC, y: currentY)
  }

  private func drawTier(in context: UIGraphicsPDFRendererContext, title: String,
                        rows: [RecruitingPacketData.SchoolRow], y: CGFloat) -> CGFloat {
    guard !rows.isEmpty else { return y }
    var currentY = ensureRoom(in: context, y: y, needed: 70)
    currentY = drawSubTitle("\(title) (\(rows.count))", y: currentY)
    currentY = drawSchoolHeader(in: context, y: currentY)
    for row in rows {
      currentY = ensureRoom(in: context, y: currentY, needed: 30)
      currentY = drawSchoolRow(row, y: currentY)
    }
    return currentY + 10
  }

  private let schoolColumns: [CGFloat] = [170, 120, 60, 110, 52]

  private func drawSchoolHeader(in context: UIGraphicsPDFRendererContext, y: CGFloat) -> CGFloat {
    let headers = ["School Name", "Location", "Div", "Conference", "Status"]
    let attributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
      .foregroundColor: UIColor.black
    ]
    var x = margin
    for (index, header) in headers.enumerated() {
      header.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
      x += schoolColumns[index]
    }
    context.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
    context.cgContext.setLineWidth(0.5)
    context.cgContext.move(to: CGPoint(x: margin, y: y + 13))
    context.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: y + 13))
    context.cgContext.strokePath()
    return y + 18
  }

  private func drawSchoolRow(_ row: RecruitingPacketData.SchoolRow, y: CGFloat) -> CGFloat {
    let attributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.systemFont(ofSize: 9),
      .foregroundColor: UIColor.black
    ]
    let values = [row.name, row.location, row.division, row.conference, row.status]
    var x = margin
    for (index, value) in values.enumerated() {
      let columnWidth = schoolColumns[index]
      let rect = CGRect(x: x, y: y, width: columnWidth - 6, height: 14)
      truncated(value, width: rect.width, font: UIFont.systemFont(ofSize: 9))
        .draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
      x += columnWidth
    }
    return y + 16
  }

  // MARK: - Footer

  private func drawFooter(context: UIGraphicsPDFRendererContext) {
    let attributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.systemFont(ofSize: 8),
      .foregroundColor: UIColor.gray
    ]
    let line1 = "This recruiting packet was generated by The Recruiting Compass."
    let line2 = "Generated on \(timestampFormatter.string(from: .now))"
    line1.draw(at: CGPoint(x: margin, y: pageHeight - margin + 6), withAttributes: attributes)
    line2.draw(at: CGPoint(x: margin, y: pageHeight - margin + 18), withAttributes: attributes)
  }

  // MARK: - Drawing helpers

  private func drawCentered(_ text: String, y: CGFloat, font: UIFont,
                            color: UIColor = .black, spacingAfter: CGFloat) -> CGFloat {
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let size = text.size(withAttributes: attributes)
    text.draw(at: CGPoint(x: (pageWidth - size.width) / 2, y: y), withAttributes: attributes)
    return y + size.height + spacingAfter
  }

  private func drawSectionTitle(_ text: String, y: CGFloat) -> CGFloat {
    let attributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.systemFont(ofSize: 18, weight: .bold),
      .foregroundColor: UIColor.black
    ]
    text.draw(at: CGPoint(x: margin, y: y), withAttributes: attributes)
    return y + 28
  }

  private func drawSubTitle(_ text: String, y: CGFloat) -> CGFloat {
    let attributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
      .foregroundColor: UIColor.black
    ]
    text.draw(at: CGPoint(x: margin, y: y), withAttributes: attributes)
    return y + 20
  }

  private func drawLabelValue(_ label: String, _ value: String, y: CGFloat) -> CGFloat {
    let labelAttributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.systemFont(ofSize: 10, weight: .medium),
      .foregroundColor: UIColor.darkGray
    ]
    let valueAttributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.systemFont(ofSize: 10),
      .foregroundColor: UIColor.black
    ]
    let labelText = "\(label): "
    labelText.draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttributes)
    let labelWidth = labelText.size(withAttributes: labelAttributes).width
    let valueWidth = pageWidth - margin - (margin + labelWidth)
    truncated(value, width: valueWidth, font: UIFont.systemFont(ofSize: 10))
      .draw(at: CGPoint(x: margin + labelWidth, y: y), withAttributes: valueAttributes)
    return y + 16
  }

  private func drawStatRow(_ stats: [(String, String)], y: CGFloat) -> CGFloat {
    let available = pageWidth - 2 * margin
    let columnWidth = available / CGFloat(stats.count)
    let labelAttributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.systemFont(ofSize: 9),
      .foregroundColor: UIColor.gray
    ]
    let valueAttributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
      .foregroundColor: UIColor.black
    ]
    for (index, stat) in stats.enumerated() {
      let x = margin + CGFloat(index) * columnWidth
      stat.0.uppercased().draw(at: CGPoint(x: x, y: y), withAttributes: labelAttributes)
      truncated(stat.1, width: columnWidth - 6, font: UIFont.systemFont(ofSize: 13, weight: .semibold))
        .draw(at: CGPoint(x: x, y: y + 12), withAttributes: valueAttributes)
    }
    return y + 44
  }

  /// If fewer than `needed` points remain before the bottom margin, start a new page.
  private func ensureRoom(in context: UIGraphicsPDFRendererContext, y: CGFloat, needed: CGFloat) -> CGFloat {
    if y + needed > pageHeight - margin {
      context.beginPage()
      return margin
    }
    return y
  }

  /// Truncates text with a trailing ellipsis so a single-line cell never overruns its column.
  private func truncated(_ text: String, width: CGFloat, font: UIFont) -> String {
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    guard text.size(withAttributes: attributes).width > width, width > 0 else { return text }
    var result = text
    while result.count > 1 && (result + "…").size(withAttributes: attributes).width > width {
      result.removeLast()
    }
    return result + "…"
  }
}
