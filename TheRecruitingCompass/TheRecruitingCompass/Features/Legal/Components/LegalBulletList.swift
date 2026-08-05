import SwiftUI

struct LegalBulletList: View {
  let items: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(items, id: \.self) { item in
        HStack(alignment: .top, spacing: 8) {
          Text("•")
            .font(.body)
            .foregroundStyle(Color.secondaryText)
          Text(item)
            .font(.body)
            .foregroundStyle(Color.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }
}
