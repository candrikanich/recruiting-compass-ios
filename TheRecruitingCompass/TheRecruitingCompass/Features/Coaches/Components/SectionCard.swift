import SwiftUI

/// Boxed section container matching the coach-detail Figma frame: an optional
/// uppercase label above content, on an elevated rounded card.
struct SectionCard<Content: View>: View {
  var label: LocalizedStringKey?
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let label {
        Text(label)
          .font(.caption.bold())
          .textCase(.uppercase)
          .foregroundStyle(Color.secondaryText)
          .tracking(0.5)
      }
      content()
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(uiColor: .secondarySystemBackground))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(uiColor: .separator), lineWidth: 1))
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
  }
}

#Preview {
  ScrollView {
    VStack(spacing: 16) {
      SectionCard(label: "Direct Channels") {
        Text("content goes here")
      }
      SectionCard {
        Text("no label")
      }
    }
    .padding()
  }
}
