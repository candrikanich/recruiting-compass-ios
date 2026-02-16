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
