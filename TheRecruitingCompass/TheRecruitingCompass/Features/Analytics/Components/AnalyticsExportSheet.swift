import SwiftUI

struct AnalyticsExportSheet: View {
  let onExport: (AnalyticsExportFormat) -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        ForEach(AnalyticsExportFormat.allCases) { format in
          Button {
            onExport(format)
            dismiss()
          } label: {
            HStack(spacing: 12) {
              Image(systemName: format.iconName)
                .font(.title3)
                .foregroundStyle(format == .pdf ? Color.accentBlue : Color.iconGray)
                .frame(width: 32)
                .accessibilityHidden(true)

              VStack(alignment: .leading, spacing: 2) {
                Text(format.displayName)
                  .font(.body)
                  .foregroundStyle(Color.darkSlate)
                Text(".\(format.fileExtension) file")
                  .font(.caption)
                  .foregroundStyle(Color.secondaryText)
              }

              Spacer()

              Image(systemName: "arrow.down.circle")
                .foregroundStyle(Color.accentBlue)
                .accessibilityHidden(true)
            }
          }
          .accessibilityLabel(String(localized: "Export as \(format.displayName)"))
          .accessibilityHint("Downloads analytics data as a .\(format.fileExtension) file")
        }
      }
      .navigationTitle("Export Analytics")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium])
  }
}
