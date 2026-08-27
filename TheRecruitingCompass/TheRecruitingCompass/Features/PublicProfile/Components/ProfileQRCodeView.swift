import CoreImage.CIFilterBuiltins
import SwiftUI

/// "Profile QR Code" card in the Setup panel's live preview — parity with web
/// `ProfileMiniPreview.vue`'s QR card ("Coaches can scan directly at
/// tournaments"). Generated on-device via CoreImage; no network round trip.
struct ProfileQRCodeView: View {
    let url: URL

    var body: some View {
        VStack(spacing: 8) {
            if let image = Self.qrImage(for: url.absoluteString) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 140, height: 140)
                    .accessibilityLabel(String(localized: "QR code linking to your public profile"))
            }
            Text(String(localized: "Coaches can scan directly at tournaments"))
                .font(.caption)
                .foregroundStyle(Color.Text.muted)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.Surface.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.Surface.border, lineWidth: 1))
    }

    static func qrImage(for string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
