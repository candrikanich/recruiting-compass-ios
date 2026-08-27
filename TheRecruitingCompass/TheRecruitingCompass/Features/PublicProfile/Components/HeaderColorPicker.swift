import SwiftUI

struct HeaderColorPicker: View {
    @Binding var selection: HeaderColor

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(HeaderColor.setupSwatches, id: \.self) { color in
                    Circle()
                        .fill(color.color)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .strokeBorder(.primary, lineWidth: selection == color ? 3 : 0)
                        )
                        .onTapGesture { selection = color }
                        .accessibilityLabel(Text(color.label))
                        .accessibilityAddTraits(selection == color ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 4)
        }
    }
}
