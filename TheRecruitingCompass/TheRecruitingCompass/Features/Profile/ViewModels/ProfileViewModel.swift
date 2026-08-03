import Foundation
import UIKit
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "ProfileViewModel")

@Observable
@MainActor
final class ProfileViewModel {

  nonisolated deinit {}

    // MARK: - Section 1: Profile Photo

    var isUploadingPhoto = false
    var photoError: String?
    var showRemovePhotoConfirm = false

    // MARK: - Section 2: Personal Information

    var fullName: String = ""
    var phone: String = ""
    var dateOfBirth: String = ""
    var isSavingPersonalInfo = false
    var personalInfoMessage: SectionMessage?

    // MARK: - Section 3: Email

    var isEmailFormExpanded = false
    var newEmail: String = ""
    var emailCurrentPassword: String = ""
    var isSavingEmail = false
    var emailMessage: SectionMessage?
    var emailVerificationBannerVisible = false

    // MARK: - Section 4: Password

    var currentPassword: String = ""
    var newPassword: String = ""
    var confirmPassword: String = ""
    var isSavingPassword = false
    var passwordMessage: SectionMessage?

    // MARK: - Section 6: Data & Privacy

    enum DeletionState {
        case noRequest
        case confirmStep
        case pending(scheduledFor: Date)
    }

    var deletionState: DeletionState = .noRequest
    var isLoadingDeletion = false
    var deletionError: String?

    // MARK: - Shared types

    enum SectionMessage {
        case success(String)
        case error(String)

        var text: String {
            switch self {
            case .success(let msg), .error(let msg): return msg
            }
        }
        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }

    // MARK: - Services

    private let profileService: ProfileManaging
    private let photoService: ProfilePhotoManaging
    private let authManager: AuthManager

    init(
        profileService: ProfileManaging? = nil,
        photoService: ProfilePhotoManaging? = nil,
        authManager: AuthManager? = nil
    ) {
        self.profileService = profileService ?? ProfileServiceImpl()
        self.photoService = photoService ?? ProfilePhotoServiceImpl()
        self.authManager = authManager ?? .shared
    }

  

    // MARK: - Load

    func loadInitialState() {
        guard let user = authManager.user else { return }
        fullName = user.fullName ?? ""
        phone = user.phone ?? ""
        dateOfBirth = user.dateOfBirth ?? ""
    }

    func loadDeletionStatus() async {
        isLoadingDeletion = true
        defer { isLoadingDeletion = false }
        do {
            let requestedAt = try await profileService.getDeletionStatus()
            if let date = requestedAt {
                let scheduledFor = Calendar.current.date(byAdding: .day, value: 30, to: date) ?? date
                deletionState = .pending(scheduledFor: scheduledFor)
            } else {
                deletionState = .noRequest
            }
        } catch {
            // intentionally silent to the user: worst case the UI offers the
            // deletion request flow again, and the server rejects duplicates.
            logger.warning("Could not fetch deletion status: \(error.localizedDescription)")
            deletionState = .noRequest
        }
    }

    // MARK: - Section 1: Photo actions

    func uploadPhoto(_ image: UIImage) async {
        guard let userId = authManager.user?.id else { return }
        isUploadingPhoto = true
        photoError = nil
        defer { isUploadingPhoto = false }

        do {
            let url = try await photoService.upload(image: image, userId: userId)
            updateCachedUser { user in
                User(
                    id: user.id,
                    email: user.email,
                    emailConfirmedAt: user.emailConfirmedAt,
                    phone: user.phone,
                    fullName: user.fullName,
                    createdAt: user.createdAt,
                    updatedAt: user.updatedAt,
                    role: user.role,
                    dateOfBirth: user.dateOfBirth,
                    profilePhotoUrl: url
                )
            }
        } catch {
            logger.error("Photo upload failed: \(error.localizedDescription)")
            photoError = error.localizedDescription
        }
    }

    func removePhoto() async {
        guard let user = authManager.user, let url = user.profilePhotoUrl else { return }
        isUploadingPhoto = true
        photoError = nil
        defer { isUploadingPhoto = false }

        do {
            try await photoService.delete(userId: user.id, currentPhotoURL: url)
            updateCachedUser { user in
                User(
                    id: user.id,
                    email: user.email,
                    emailConfirmedAt: user.emailConfirmedAt,
                    phone: user.phone,
                    fullName: user.fullName,
                    createdAt: user.createdAt,
                    updatedAt: user.updatedAt,
                    role: user.role,
                    dateOfBirth: user.dateOfBirth,
                    profilePhotoUrl: nil
                )
            }
        } catch {
            logger.error("Photo remove failed: \(error.localizedDescription)")
            photoError = error.localizedDescription
        }
    }

    // MARK: - Section 2: Personal info

    var isPersonalInfoValid: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func savePersonalInfo() async {
        guard isPersonalInfoValid, !isSavingPersonalInfo else { return }
        isSavingPersonalInfo = true
        personalInfoMessage = nil
        defer { isSavingPersonalInfo = false }

        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phoneVal = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let dobVal = dateOfBirth.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await profileService.updatePersonalInfo(
                fullName: trimmedName,
                phone: phoneVal.isEmpty ? nil : phoneVal,
                dateOfBirth: dobVal.isEmpty ? nil : dobVal
            )
            updateCachedUser { user in
                User(
                    id: user.id,
                    email: user.email,
                    emailConfirmedAt: user.emailConfirmedAt,
                    phone: phoneVal.isEmpty ? nil : phoneVal,
                    fullName: trimmedName,
                    createdAt: user.createdAt,
                    updatedAt: user.updatedAt,
                    role: user.role,
                    dateOfBirth: dobVal.isEmpty ? nil : dobVal,
                    profilePhotoUrl: user.profilePhotoUrl
                )
            }
            personalInfoMessage = .success("Saved!")
            try? await Task.sleep(for: .seconds(2))
            personalInfoMessage = nil
        } catch {
            logger.error("Personal info save failed: \(error.localizedDescription)")
            personalInfoMessage = .error("Failed to save. Please try again.")
        }
    }

    // MARK: - Section 3: Email

    func submitEmailChange() async {
        guard !isSavingEmail else { return }
        isSavingEmail = true
        emailMessage = nil
        defer { isSavingEmail = false }

        do {
            try await profileService.changeEmail(newEmail: newEmail, currentPassword: emailCurrentPassword)
            isEmailFormExpanded = false
            newEmail = ""
            emailCurrentPassword = ""
            emailVerificationBannerVisible = true
        } catch let error as ProfileServiceError {
            logger.error("Email change failed: \(error.localizedDescription)")
            emailMessage = .error(error.errorDescription ?? "Failed to update email.")
        } catch {
            emailMessage = .error("Failed to update email.")
        }
    }

    // MARK: - Section 4: Password

    var passwordsMatch: Bool { newPassword == confirmPassword }

    var isPasswordFormValid: Bool {
        !currentPassword.isEmpty && newPassword.count >= 8 && passwordsMatch
    }

    func savePassword() async {
        guard isPasswordFormValid, !isSavingPassword else { return }
        isSavingPassword = true
        passwordMessage = nil
        defer { isSavingPassword = false }

        do {
            try await profileService.changePassword(currentPassword: currentPassword, newPassword: newPassword)
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
            passwordMessage = .success("Password updated!")
            try? await Task.sleep(for: .seconds(2))
            passwordMessage = nil
        } catch let error as ProfileServiceError {
            logger.error("Password change failed: \(error.localizedDescription)")
            passwordMessage = .error(error.errorDescription ?? "Failed to change password.")
        } catch {
            passwordMessage = .error("Failed to change password.")
        }
    }

    // MARK: - Section 6: Deletion

    func beginDeletionRequest() {
        deletionState = .confirmStep
    }

    func cancelDeletionConfirm() {
        deletionState = .noRequest
    }

    func confirmDeletion() async {
        isLoadingDeletion = true
        deletionError = nil
        defer { isLoadingDeletion = false }

        do {
            try await profileService.requestDeletion()
            let scheduledFor = Calendar.current.date(byAdding: .day, value: 30, to: Date.now) ?? Date.now
            deletionState = .pending(scheduledFor: scheduledFor)
        } catch {
            logger.error("Deletion request failed: \(error.localizedDescription)")
            deletionError = error.localizedDescription
            deletionState = .noRequest
        }
    }

    func cancelDeletionRequest() async {
        isLoadingDeletion = true
        deletionError = nil
        defer { isLoadingDeletion = false }

        do {
            try await profileService.cancelDeletion()
            deletionState = .noRequest
        } catch {
            logger.error("Cancel deletion failed: \(error.localizedDescription)")
            deletionError = error.localizedDescription
        }
    }

    // MARK: - Private

    private func updateCachedUser(_ transform: (User) -> User) {
        guard let user = authManager.user else { return }
        authManager.updateUser(transform(user))
    }
}
