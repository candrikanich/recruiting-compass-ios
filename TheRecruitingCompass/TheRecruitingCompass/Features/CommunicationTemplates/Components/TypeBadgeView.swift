import SwiftUI

struct TypeBadgeView: View {
  let type: TemplateType

  var body: some View {
    Text(type.displayName)
      .font(.caption.weight(.medium))
      .foregroundStyle(type.color)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(type.color.opacity(0.15))
      .clipShape(Capsule())
  }
}
