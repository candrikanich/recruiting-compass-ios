import Foundation

struct InteractionData {
  var type: InteractionType = .inPersonVisit
  var direction: Direction = .inbound
  var sentiment: Sentiment = .neutral
  var notes: String = ""
  var coachId: String?
}
