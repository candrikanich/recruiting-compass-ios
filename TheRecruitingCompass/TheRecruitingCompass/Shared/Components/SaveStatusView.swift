import SwiftUI

struct SaveStatusView: View {
    let status: SaveStatus

    var body: some View {
        statusContent
            .animation(.easeInOut(duration: 0.2), value: status)
            .onChange(of: status) { _, newStatus in
                guard let announcement = newStatus.announcement else { return }
                // Low priority so an autosave never interrupts what VoiceOver is already reading.
                var text = AttributedString(announcement)
                text.accessibilitySpeechAnnouncementPriority = .low
                AccessibilityNotification.Announcement(text).post()
            }
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
                    .font(.brand(.caption))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        case .saved:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                Text("Saved")
                    .font(.brand(.caption))
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
