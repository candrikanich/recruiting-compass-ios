import MessageUI
import SwiftUI

/// SwiftUI wrapper around `MFMessageComposeViewController` — an in-app text composer that reports a
/// real send result. Present ONLY after checking `MFMessageComposeViewController.canSendText()`.
/// `onResult` fires once with the final result.
struct MessageComposeView: UIViewControllerRepresentable {
  let recipients: [String]
  let body: String?
  let onResult: (MessageComposeResult) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onResult: onResult)
  }

  func makeUIViewController(context: Context) -> MFMessageComposeViewController {
    let controller = MFMessageComposeViewController()
    controller.messageComposeDelegate = context.coordinator
    controller.recipients = recipients.filter { !$0.isEmpty }
    if let body, !body.isEmpty { controller.body = body }
    return controller
  }

  func updateUIViewController(_ controller: MFMessageComposeViewController, context: Context) {}

  final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
    private let onResult: (MessageComposeResult) -> Void

    init(onResult: @escaping (MessageComposeResult) -> Void) {
      self.onResult = onResult
    }

    func messageComposeViewController(
      _ controller: MFMessageComposeViewController,
      didFinishWith result: MessageComposeResult
    ) {
      controller.dismiss(animated: true) { [onResult] in
        onResult(result)
      }
    }
  }
}
