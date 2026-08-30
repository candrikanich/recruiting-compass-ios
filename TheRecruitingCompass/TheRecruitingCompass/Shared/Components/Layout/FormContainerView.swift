import SwiftUI

struct FormContainerView<Content: View>: View {
    let maxWidth: CGFloat
    @ViewBuilder let content: () -> Content
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(
        maxWidth: CGFloat = 672,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.maxWidth = maxWidth
        self.content = content
    }

    var body: some View {
        if sizeClass == .regular {
            ScrollView {
                VStack(spacing: 16) {
                    content()
                }
                .frame(maxWidth: maxWidth)
                .padding(.vertical, 24)
                .padding(.horizontal, 32)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .background(Color(.systemGroupedBackground))
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    content()
                }
                .padding()
            }
        }
    }
}
