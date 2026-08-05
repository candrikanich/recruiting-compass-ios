import SwiftUI

struct CommunicationButton: View {
  let type: CommunicationType
  let value: String

  @Environment(\.openURL) private var openURL
  @Environment(\.sizeCategory) private var sizeCategory

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 24 : 18
  }

  var body: some View {
    Button {
      if let url = type.url(for: value) {
        openURL(url)
      }
    } label: {
      Image(systemName: type.iconName)
        .font(.system(size: iconSize))
        .foregroundStyle(type.iconColor)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }
    .accessibilityLabel(type.accessibilityLabel)
    .accessibilityHint("Opens \(type.appName)")
  }
}

#Preview {
  HStack(spacing: 8) {
    CommunicationButton(type: .email("test@example.com"), value: "test@example.com")
    CommunicationButton(type: .phone("555-1234"), value: "555-1234")
    CommunicationButton(type: .call("555-1234"), value: "555-1234")
    CommunicationButton(type: .twitter("@coach"), value: "@coach")
    CommunicationButton(type: .instagram("@coach"), value: "@coach")
  }
}
