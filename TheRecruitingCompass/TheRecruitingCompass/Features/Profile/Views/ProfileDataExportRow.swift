import SwiftUI

struct ProfileDataExportRow: View {
    @Bindable var viewModel: ProfileViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Download a copy of all your data as a ZIP file. You can request one export per day.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let url = viewModel.exportDownloadURL {
                ShareLink(item: url) {
                    Label(String(localized: "Share or Save Export"), systemImage: "square.and.arrow.up")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(String(localized: "Share or save your data export"))
            } else {
                Button {
                    Task { await viewModel.requestDataExport() }
                } label: {
                    HStack {
                        if viewModel.isExportingData { ProgressView() }
                        Text(viewModel.isExportingData ? "Preparing Export…" : "Export My Data")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isExportingData)
                .accessibilityLabel(String(localized: "Export my data"))
            }

            if let error = viewModel.exportError {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(Color.errorRed)
                    .accessibilityLabel(String(localized: "Error: \(error)"))
            }
        }
        .padding(.vertical, 4)
    }
}
