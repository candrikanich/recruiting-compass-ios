import SwiftUI

struct ExportFormatSheet: View {
  let csvData: Data
  let pdfData: Data
  @Environment(\.dismiss) private var dismiss
  @Environment(\.sizeCategory) private var sizeCategory
  @State private var selectedFormat: ExportFormat = .csv
  @State private var showShareSheet = false

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 56 : 48
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        // Icon
        Image(systemName: "square.and.arrow.up")
          .font(.system(size: iconSize))
          .foregroundStyle(Color.accentBlue)
          .padding(.top)

        // Title
        Text("Export Metrics")
          .font(.title2)
          .bold()

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
    let dateString = dateFormatter.string(from: .now)
    return "performance_metrics_\(dateString).\(selectedFormat.rawValue.lowercased())"
  }
}

#Preview {
  ExportFormatSheet(
    csvData: "test,data\n1,2".data(using: .utf8)!,
    pdfData: Data()
  )
}
