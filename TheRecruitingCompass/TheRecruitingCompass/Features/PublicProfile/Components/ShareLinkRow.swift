import SwiftUI

struct ShareLinkRow: View {
    let url: URL?
    var onCopy: () -> Void

    var body: some View {
        HStack {
            if let url {
                Text(url.absoluteString)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(action: onCopy) {
                    Label(String(localized: "Copy"), systemImage: "doc.on.doc")
                }
                .accessibilityLabel(Text(String(localized: "Copy profile link")))
            } else {
                Text(
                    String(localized: "Publish your profile to get a shareable link.")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}
