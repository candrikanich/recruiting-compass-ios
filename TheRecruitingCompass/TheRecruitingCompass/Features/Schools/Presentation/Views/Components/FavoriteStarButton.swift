import SwiftUI

struct FavoriteStarButton: View {
  let isFavorite: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: isFavorite ? "star.fill" : "star")
        .foregroundStyle(isFavorite ? .yellow : .gray)
        .accessibilityHidden(true)
    }
    .frame(width: 44, height: 44)
    .accessibilityLabel(isFavorite ? String(localized: "Remove from favorites") : String(localized: "Add to favorites"))
    .accessibilityHint("Double tap to toggle favorite status")
    .accessibilityValue(isFavorite ? "Favorited" : "Not favorited")
    .accessibilityAddTraits(.isButton)
  }
}

#Preview {
  HStack(spacing: 20) {
    FavoriteStarButton(isFavorite: true) {}
    FavoriteStarButton(isFavorite: false) {}
  }
  .padding()
}
