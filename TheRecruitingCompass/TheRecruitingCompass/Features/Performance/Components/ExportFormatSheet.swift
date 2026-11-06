import SwiftUI

struct ExportFormatSheet: View {
  let csvData: Data
  let pdfData: Data
  @Environment(\.dismiss) private var dismiss
  @Environment(\.sizeCategory) private var sizeCategory
  @State private var selectedFormat: ExportFormat = .csv
  @State private var exportFile: PerformanceExportFile?
  @State private var showExportError = false

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 56 : 48
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        // Icon
        Image(systemName: "square.and.arrow.up")
          .font(.system(size: iconSize))
          .foregroundStyle(Color.accentPrimary)
          .padding(.top)

        // Title
        Text("Export Metrics")
          .font(.brand(.title2))
          .bold()

        // Format Selection
        VStack(alignment: .leading, spacing: 12) {
          Text("Select Format")
            .font(.brand(.subheadline))
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
          export()
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
      .sheet(item: $exportFile) { file in
        ActivityShareSheet(activityItems: [file.url])
      }
      .alert("Export Failed", isPresented: $showExportError) {
      } message: {
        Text("Couldn't create the export file. Please try again.")
      }
    }
  }

  private var currentFormatData: Data {
    selectedFormat == .csv ? csvData : pdfData
  }

  private func export() {
    do {
      exportFile = try PerformanceExportFile.write(currentFormatData, named: selectedFormat.filename(on: .now))
    } catch {
      showExportError = true
    }
  }
}

#Preview {
  ExportFormatSheet(
    csvData: "test,data\n1,2".data(using: .utf8)!,
    pdfData: Data()
  )
}
