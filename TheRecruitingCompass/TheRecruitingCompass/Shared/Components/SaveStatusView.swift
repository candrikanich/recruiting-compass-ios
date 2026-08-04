import SwiftUI

struct SaveStatusView: View {
    let status: SaveStatus

    var body: some View {
        statusContent
            .animation(.easeInOut(duration: 0.2), value: status)
    }

    @ViewBuilder
    private var statusContent: some View {
        switch status {
        case .idle:
            EmptyView()
        case .saving:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Saving...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .saved:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SaveStatusView(status: .idle)
        SaveStatusView(status: .saving)
        SaveStatusView(status: .saved)
    }
    .padding()
}
