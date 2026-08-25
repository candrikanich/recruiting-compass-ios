import SwiftUI

/// School favicon avatar with a gradient-initials fallback.
///
/// Shared by the coach card and the coach detail header so both render one logo
/// treatment: the school's favicon when it resolves, the gradient initials when
/// there is no school, no favicon URL, or the image fails to load. Never a photo.
struct SchoolLogoAvatar: View {
  let logoUrl: String?
  let initials: String
  var size: CGFloat = 48
  var accessibilitySize: CGFloat = 56
  var cornerRadius: CGFloat = 10
  var initialsFont: Font?

  @Environment(\.sizeCategory) private var sizeCategory

  private var resolvedSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? accessibilitySize : size
  }

  private var resolvedFont: Font {
    initialsFont ?? (sizeCategory.isAccessibilityCategory ? .title2.bold() : .body.bold())
  }

  var body: some View {
    Group {
      if let logoUrl, let url = URL(string: logoUrl) {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .scaledToFit()
          case .failure, .empty:
            initialsFallback
          @unknown default:
            initialsFallback
          }
        }
      } else {
        initialsFallback
      }
    }
    .frame(width: resolvedSize, height: resolvedSize)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    .accessibilityHidden(true)
  }

  @ViewBuilder private var initialsFallback: some View {
    Text(initials)
      .font(resolvedFont)
      .foregroundStyle(.white)
      .frame(width: resolvedSize, height: resolvedSize)
      .background(
        LinearGradient(
          colors: [.blueGradientStart, Color(hex: "7C3AED")],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
  }
}

#Preview {
  HStack(spacing: 24) {
    SchoolLogoAvatar(logoUrl: nil, initials: "SU")
    SchoolLogoAvatar(
      logoUrl: nil,
      initials: "JS",
      size: 100,
      accessibilitySize: 120,
      cornerRadius: 24,
      initialsFont: .largeTitle.bold()
    )
  }
  .padding()
}
