import MessageUI
import SwiftUI

/// SwiftUI wrapper around `MFMailComposeViewController` — an in-app mail composer that reports a
/// real send result. Present ONLY after checking `MFMailComposeViewController.canSendMail()`;
/// with no Mail account the composer cannot send. `onResult` fires once with the final result.
struct MailComposeView: UIViewControllerRepresentable {
  let recipients: [String]
  let subject: String?
  let body: String?
  let onResult: (MFMailComposeResult, Error?) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onResult: onResult)
  }

  func makeUIViewController(context: Context) -> MFMailComposeViewController {
    let controller = MFMailComposeViewController()
    controller.mailComposeDelegate = context.coordinator
    controller.setToRecipients(recipients.filter { !$0.isEmpty })
    if let subject, !subject.isEmpty { controller.setSubject(subject) }
    if let body, !body.isEmpty { controller.setMessageBody(body, isHTML: false) }
    return controller
  }

  func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

  final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
    private let onResult: (MFMailComposeResult, Error?) -> Void

    init(onResult: @escaping (MFMailComposeResult, Error?) -> Void) {
      self.onResult = onResult
    }

    func mailComposeController(
      _ controller: MFMailComposeViewController,
      didFinishWith result: MFMailComposeResult,
      error: Error?
    ) {
      controller.dismiss(animated: true) { [onResult] in
        onResult(result, error)
      }
    }
  }
}
