import Foundation

/// Represents different types of alerts that can be shown in School Detail
enum AlertType: Identifiable {
  case error(String)
  case deleteError(String)
  case deleteConfirmation

  var id: String {
    switch self {
    case .error(let msg):
      return "error:\(msg)"
    case .deleteError(let msg):
      return "deleteError:\(msg)"
    case .deleteConfirmation:
      return "deleteConfirmation"
    }
  }

  var title: String {
    switch self {
    case .error:
      return "Error"
    case .deleteError:
      return "Delete Failed"
    case .deleteConfirmation:
      return "Delete School?"
    }
  }

  var message: String {
    switch self {
    case .error(let msg), .deleteError(let msg):
      return msg
    case .deleteConfirmation:
      return "This will permanently delete the school and all related data. This action cannot be undone."
    }
  }
}
