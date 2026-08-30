import SwiftUI

struct AdaptiveDetailLayout<Content: View, Sidebar: View>: View {
    let sidebarPlacement: SidebarPlacement
    let sidebarWidth: CGFloat
    @ViewBuilder let content: () -> Content
    @ViewBuilder let sidebar: () -> Sidebar
    @Environment(\.horizontalSizeClass) private var sizeClass

    enum SidebarPlacement {
        case leading
        case trailing
    }

    init(
        sidebarPlacement: SidebarPlacement,
        sidebarWidth: CGFloat = 300,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder sidebar: @escaping () -> Sidebar
    ) {
        self.sidebarPlacement = sidebarPlacement
        self.sidebarWidth = sidebarWidth
        self.content = content
        self.sidebar = sidebar
    }

    var body: some View {
        if sizeClass == .regular {
            regularLayout
        } else {
            compactLayout
        }
    }

    private var regularLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            if sidebarPlacement == .leading {
                sidebarColumn
                Divider()
            }

            ScrollView {
                content()
                    .padding()
            }
            .frame(maxWidth: .infinity)

            if sidebarPlacement == .trailing {
                Divider()
                sidebarColumn
            }
        }
    }

    private var sidebarColumn: some View {
        ScrollView {
            sidebar()
                .padding()
        }
        .frame(width: sidebarWidth)
        .background(Color(.systemGroupedBackground))
    }

    private var compactLayout: some View {
        ScrollView {
            VStack(spacing: 16) {
                content()
                sidebar()
            }
            .padding()
        }
    }
}
