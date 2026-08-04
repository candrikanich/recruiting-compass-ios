import Foundation

enum MorePath: Hashable {
  case section(MoreMenuSection)
  case eventDetail(eventId: String)
  case offerDetail(offerId: String)
  case helpSection(slug: String)
}
