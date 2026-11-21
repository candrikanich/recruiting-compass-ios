import SwiftUI

/// Brand accent for a dashboard stat tile (web#1522 parity): a 3 pt top border plus a tinted icon chip.
/// Dark values are lifted so the border and icon keep AA contrast on dark cards.
enum StatAccent: CaseIterable {
  case forest
  case gold

  var border: Color {
    switch self {
    case .forest: Color.Category.forest
    case .gold: Color.Category.gold
    }
  }

  var chipFill: Color {
    switch self {
    case .forest: Color(light: Color.Brand.forest100, dark: Color.Brand.forest900)
    case .gold: Color(light: Color.Brand.gold100, dark: Color.Brand.gold900)
    }
  }

  var icon: Color {
    switch self {
    case .forest: Color(light: Color.Brand.forest700, dark: Color.Brand.forest200)
    case .gold: Color(light: Color.Brand.gold700, dark: Color.Brand.gold200)
    }
  }
}

/// Home stat metrics and their accent. forest = core progress, gold = neutral activity volume.
/// Web also has Offers (forest) and Last Contact (clay); iOS Home has no tile for either.
enum StatMetric {
  case coaches
  case schools
  case interactions
  case events

  var accent: StatAccent {
    switch self {
    case .coaches, .schools: .forest
    case .interactions, .events: .gold
    }
  }
}
