import Foundation

enum SaveStatus: Equatable {
    case idle
    case saving
    case saved

    /// What VoiceOver says when the status changes. Only completion is announced: autosave fires on every
    /// edit, and "Saving" each time would talk over the user.
    var announcement: String? {
        switch self {
        case .idle, .saving: return nil
        case .saved: return String(localized: "Changes saved")
        }
    }
}
