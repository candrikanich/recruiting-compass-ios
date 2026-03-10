import Foundation

enum OfferAlertType: Identifiable {
  case error(String)
  case deleteConfirmation
  case deleteError(String)

  var id: String {
    switch self {
    case .error(let msg): return "error:\(msg)"
    case .deleteConfirmation: return "deleteConfirmation"
    case .deleteError(let msg): return "deleteError:\(msg)"
    }
  }

  var title: String {
    switch self {
    case .error: return "Error"
    case .deleteConfirmation: return "Delete Offer?"
    case .deleteError: return "Delete Failed"
    }
  }
}
