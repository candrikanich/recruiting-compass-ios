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

  @ViewBuilder
  private var regularLayout: some View {
    GeometryReader { geo in
      let resolvedSidebarWidth = min(sidebarWidth, geo.size.width * 0.38)

      HStack(alignment: .top, spacing: 16) {
        if sidebarPlacement == .leading {
          sidebarColumn(width: resolvedSidebarWidth)
        }

        ScrollView {
          content()
            .padding()
        }
        .frame(maxWidth: .infinity)

        if sidebarPlacement == .trailing {
          sidebarColumn(width: resolvedSidebarWidth)
        }
      }
    }
  }

  @ViewBuilder
  private func sidebarColumn(width: CGFloat) -> some View {
    let gutterEdge: Edge.Set = sidebarPlacement == .leading ? .trailing : .leading
    ScrollView {
      sidebar()
        .padding()
        .padding(gutterEdge, 8)
    }
    .frame(width: width)
    .clipped()
    .background(Color(.systemGroupedBackground))
  }

  @ViewBuilder
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
