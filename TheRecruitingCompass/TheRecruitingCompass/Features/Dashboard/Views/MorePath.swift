import Foundation

enum MorePath: Hashable {
  case section(MoreMenuSection)
  case eventDetail(eventId: String)
  case offerDetail(offerId: String)
  case helpSection(slug: String)
  case familyManagement
}

extension MorePath {
  /// Analytics screen name for a More-menu destination. Detail pages return nil: their
  /// section was already recorded when it was opened.
  var screenName: String? {
    switch self {
    case .section(let section): return section.rawValue
    case .familyManagement: return "familyManagement"
    case .eventDetail, .offerDetail, .helpSection: return nil
    }
  }
}
