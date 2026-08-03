import Foundation
import SwiftUI
import Observation
import PhotosUI
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "PlayerDetailsViewModel")

@Observable
@MainActor
final class PlayerDetailsViewModel {

    var details: PlayerDetails = .default
    var isLoading = false
    var isUploadingPhoto = false
    var errorMessage: String?
    var profileImage: UIImage?
    var isReadOnly = false
    var showDeletePhotoConfirmation = false
    var saveStatus: SaveStatus = .idle
    var selectedTab: Int = 0

    // Backward-compat computed wrappers (existing tests use these)
    var isSaving: Bool { saveStatus == .saving }
    var hasUnsavedChanges: Bool { saveStatus == .saving }
    var successMessage: String? { saveStatus == .saved ? "Saved" : nil }

    private let preferenceService: any PreferenceManaging
    private let userRole: UserRole
    @ObservationIgnored nonisolated(unsafe) private var pendingAutoSave: Task<Void, Never>?
    @ObservationIgnored nonisolated(unsafe) private var pendingStatusReset: Task<Void, Never>?

    init(preferenceService: any PreferenceManaging, userRole: UserRole) {
        self.preferenceService = preferenceService
        self.userRole = userRole
        self.isReadOnly = (userRole == .parent)
    }

    nonisolated deinit {
        pendingAutoSave?.cancel()
        pendingStatusReset?.cancel()
    }

    // MARK: - Completeness

    var completenessScore: Double {
        var fields: [Bool] = [
            details.graduationYear != nil,
            !(details.highSchool ?? "").isEmpty,
            !(details.primarySport ?? "").isEmpty,
            !(details.schoolName ?? "").isEmpty,
            !(details.schoolCity ?? "").isEmpty,
            !(details.schoolState ?? "").isEmpty,
            details.heightInches != nil,
            details.weightLbs != nil,
            details.gpa != nil,
            details.satScore != nil,
            details.actScore != nil,
            !(details.twitterHandle ?? "").isEmpty || !(details.instagramHandle ?? "").isEmpty,
        ]
        if isBaseballOrSoftball {
            fields.append(details.bats != nil)
            fields.append(details.throws_ != nil)
        }
        let filled = fields.filter { $0 }.count
        return Double(filled) / Double(fields.count)
    }

    var isBaseballOrSoftball: Bool {
        guard let sport = details.primarySport?.lowercased() else { return false }
        return sport == "baseball" || sport == "softball"
    }

    // MARK: - Auto-Save

    func scheduleAutoSave() {
        guard !isReadOnly else { return }
        pendingAutoSave?.cancel()
        saveStatus = .saving
        pendingAutoSave = Task {
            try? await Task.sleep(for: .milliseconds(1000))
            guard !Task.isCancelled else { return }
            // Unstructured task so cancelling pendingAutoSave (next keystroke)
            // only ever kills the debounce delay, never an in-flight save.
            Task { await self.saveDetails() }
        }
    }

    func markChanged() {
        guard !isReadOnly else { return }
        scheduleAutoSave()
    }

    // MARK: - Load/Save

    func loadDetails() async {
        logger.debug("Loading player details")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if let savedDetails: PlayerDetails = try await preferenceService.fetchPreferences(category: .player) {
                details = savedDetails
                logger.info("Loaded existing player details")
            } else {
                details = .default
                logger.info("No existing details, using defaults")
            }
            saveStatus = .idle
        } catch {
            logger.error("Failed to load details: \(error.localizedDescription)")
            errorMessage = "Failed to load player details. Please try again."
        }
    }

    func saveDetails() async {
        guard !isReadOnly else { return }
        logger.debug("Saving player details")
        saveStatus = .saving
        normalizePositions()
        do {
            _ = try await preferenceService.savePreferences(category: .player, data: details)
            saveStatus = .saved
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            logger.info("Player details saved")
            pendingStatusReset?.cancel()
            pendingStatusReset = Task {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                if self.saveStatus == .saved { self.saveStatus = .idle }
            }
        } catch {
            logger.error("Failed to save details: \(error.localizedDescription)")
            errorMessage = "Failed to save player details. Please try again."
            saveStatus = .idle
        }
    }

    func triggerFitScoreRecalculation() {
        Task {
            logger.info("Fit score recalculation triggered (stub — wire to API when available)")
        }
    }

    // MARK: - Photo Upload

    func uploadProfilePhoto(_ image: UIImage) async {
        guard !isReadOnly else { return }
        logger.debug("Uploading profile photo")
        isUploadingPhoto = true
        errorMessage = nil
        do {
            guard let compressedData = image.jpegData(compressionQuality: 0.7) else {
                throw PhotoError.compressionFailed
            }
            guard compressedData.count <= 5_000_000 else {
                throw PhotoError.fileTooLarge
            }
            profileImage = image
            markChanged()
            logger.info("Profile photo uploaded successfully")
            isUploadingPhoto = false
        } catch {
            logger.error("Failed to upload photo: \(error.localizedDescription)")
            errorMessage = "Failed to upload photo. Please try again."
            isUploadingPhoto = false
        }
    }

    func deleteProfilePhoto() async {
        guard !isReadOnly else { return }
        profileImage = nil
        markChanged()
        logger.info("Profile photo deleted")
    }

    // MARK: - Field Updates

    func updateGraduationYear(_ value: Int?) {
        details.graduationYear = value
        markChanged()
    }

    func updateGPA(_ value: Double?) {
        if let gpa = value, gpa >= 0.0 && gpa <= 5.0 {
            details.gpa = gpa
            markChanged()
        } else if value == nil {
            details.gpa = nil
            markChanged()
        }
    }

    func updateSAT(_ value: Int?) {
        if let sat = value, sat >= 400 && sat <= 1600 {
            details.satScore = sat
            markChanged()
        } else if value == nil {
            details.satScore = nil
            markChanged()
        }
    }

    func updateACT(_ value: Int?) {
        if let act = value, act >= 1 && act <= 36 {
            details.actScore = act
            markChanged()
        } else if value == nil {
            details.actScore = nil
            markChanged()
        }
    }

    func updateHeight(feet: Int, inches: Int) {
        details.heightInches = (feet * 12) + inches
        markChanged()
    }

    func normalizePositions() {
        details.positions = details.positions?.map { pos in
            pos.split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                .joined(separator: " ")
        }
    }

    // MARK: - Computed

    var heightFeet: Int { (details.heightInches ?? 0) / 12 }
    var heightInchesRemainder: Int { (details.heightInches ?? 0) % 12 }
}

enum PhotoError: LocalizedError {
    case compressionFailed
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .compressionFailed: return "Failed to compress photo"
        case .fileTooLarge: return "Photo must be less than 5MB"
        }
    }
}
