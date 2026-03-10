import Foundation
import UIKit
import Supabase
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "ProfilePhotoService")

private let bucket = "profile-photos"

enum ProfilePhotoError: LocalizedError {
    case compressionFailed
    case uploadFailed(Error)
    case deleteFailed(Error)
    case updateRecordFailed(Error)

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to process the image. Please try a different photo."
        case .uploadFailed:
            return "Failed to upload photo. Please try again."
        case .deleteFailed:
            return "Failed to remove photo. Please try again."
        case .updateRecordFailed:
            return "Photo uploaded but profile could not be updated. Please try again."
        }
    }
}

protocol ProfilePhotoManaging: Sendable {
    func upload(image: UIImage, userId: String) async throws -> String
    func delete(userId: String, currentPhotoURL: String) async throws
}

final class ProfilePhotoServiceImpl: ProfilePhotoManaging, Sendable {
    private let supabaseManager: SupabaseManager

    init(supabaseManager: SupabaseManager = .shared) {
        self.supabaseManager = supabaseManager
    }

    func upload(image: UIImage, userId: String) async throws -> String {
        guard let data = compress(image) else {
            throw ProfilePhotoError.compressionFailed
        }

        let timestamp = Int(Date.now.timeIntervalSince1970)
        let path = "\(userId)/profile-\(timestamp).jpg"

        logger.debug("Uploading profile photo to \(path)")

        do {
            try await supabaseManager.client.storage
                .from(bucket)
                .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        } catch {
            logger.error("Photo upload failed: \(error.localizedDescription)")
            throw ProfilePhotoError.uploadFailed(error)
        }

        let publicURL = (try? supabaseManager.client.storage
            .from(bucket)
            .getPublicURL(path: path))?.absoluteString ?? ""

        do {
            try await supabaseManager.client
                .from("users")
                .update(["profile_photo_url": publicURL])
                .eq("id", value: userId)
                .execute()
        } catch {
            logger.error("Failed to update profile_photo_url: \(error.localizedDescription)")
            throw ProfilePhotoError.updateRecordFailed(error)
        }

        logger.info("Profile photo uploaded: \(path)")
        return publicURL
    }

    func delete(userId: String, currentPhotoURL: String) async throws {
        let storagePath = extractStoragePath(from: currentPhotoURL)

        if !storagePath.isEmpty {
            do {
                try await supabaseManager.client.storage
                    .from(bucket)
                    .remove(paths: [storagePath])
            } catch {
                logger.warning("Storage delete failed (continuing): \(error.localizedDescription)")
            }
        }

        do {
            try await supabaseManager.client
                .from("users")
                .update(["profile_photo_url": AnyJSON.null])
                .eq("id", value: userId)
                .execute()
        } catch {
            logger.error("Failed to clear profile_photo_url: \(error.localizedDescription)")
            throw ProfilePhotoError.deleteFailed(error)
        }

        logger.info("Profile photo removed for user \(userId, privacy: .private)")
    }

    // MARK: - Private helpers

    private func compress(_ image: UIImage) -> Data? {
        let maxDimension: CGFloat = 1024
        let size = image.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        // Try progressively lower quality until under 1 MB
        for quality in stride(from: 0.8, through: 0.3, by: -0.1) {
            if let data = resized.jpegData(compressionQuality: quality), data.count <= 1_000_000 {
                return data
            }
        }
        return resized.jpegData(compressionQuality: 0.3)
    }

    /// Extracts the storage path (everything after `/profile-photos/`) from a public URL.
    private func extractStoragePath(from urlString: String) -> String {
        guard let range = urlString.range(of: "/\(bucket)/") else { return "" }
        return String(urlString[range.upperBound...])
    }
}
