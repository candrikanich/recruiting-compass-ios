import SwiftUI

/// Loads Send Profile state for a coach and reloads it whenever the selected athlete changes
/// (or family data arrives late), so the screen never keeps another athlete's link.
struct SendProfileLoadModifier: ViewModifier {
    let viewModel: SendProfileViewModel
    let coachId: String

    func body(content: Content) -> some View {
        content.task(id: viewModel.selectionKey) {
            await viewModel.loadTrackingInfo(for: coachId)
        }
    }
}
