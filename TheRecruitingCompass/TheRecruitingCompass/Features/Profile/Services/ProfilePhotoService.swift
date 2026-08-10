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
    /// The current profile photo URL for a user (self or a family athlete, RLS-gated).
    func currentPhotoURL(userId: String) async throws -> String?
    /// The display name (`full_name`) for a user (self or a family athlete, RLS-gated).
    func fullName(userId: String) async throws -> String?
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
            try await setProfilePhotoURL(userId: userId, url: .string(publicURL))
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
            try await setProfilePhotoURL(userId: userId, url: .null)
        } catch {
            logger.error("Failed to clear profile_photo_url: \(error.localizedDescription)")
            throw ProfilePhotoError.deleteFailed(error)
        }

        logger.info("Profile photo removed for user \(userId, privacy: .private)")
    }

    func currentPhotoURL(userId: String) async throws -> String? {
        struct Row: Decodable { let profile_photo_url: String? }
        let row: Row = try await supabaseManager.client
            .from("users")
            .select("profile_photo_url")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        return row.profile_photo_url
    }

    func fullName(userId: String) async throws -> String? {
        struct Row: Decodable { let full_name: String? }
        let row: Row = try await supabaseManager.client
            .from("users")
            .select("full_name")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        return row.full_name
    }

    // MARK: - Private helpers

    /// Persists profile_photo_url via a SECURITY DEFINER RPC so a parent can set a family
    /// athlete's photo (and a user their own). Column-scoped; RLS on `users` stays self-only.
    private func setProfilePhotoURL(userId: String, url: AnyJSON) async throws {
        try await supabaseManager.client
            .rpc("set_athlete_profile_photo", params: ["athlete_id": AnyJSON.string(userId), "photo_url": url])
            .execute()
    }

    private func compress(_ image: UIImage) -> Data? {
        ImageCompression.downsampledJPEGData(from: image)
    }

    /// Extracts the storage path (everything after `/profile-photos/`) from a public URL.
    private func extractStoragePath(from urlString: String) -> String {
        guard let range = urlString.range(of: "/\(bucket)/") else { return "" }
        return String(urlString[range.upperBound...])
    }
}
