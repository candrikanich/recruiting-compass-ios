import Foundation

/// Context passed when presenting Quick Communication for a coach.
struct QuickCommunicationContext: Identifiable {
  let coach: Coach
  let schoolName: String?

  var id: String { coach.id }
}
