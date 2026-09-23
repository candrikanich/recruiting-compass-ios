import Foundation
import Supabase
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "ProfileService")

// MARK: - Errors

enum ProfileServiceError: LocalizedError {
    case notConfigured
    case wrongPassword
    case serverError(String)
    case networkError(Error)
    case noPendingDeletion
    case exportRateLimited

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Service is not available."
        case .wrongPassword:
            return "Current password is incorrect."
        case .serverError(let message):
            return message
        case .networkError:
            return "Network error. Please check your connection."
        case .noPendingDeletion:
            return "No pending deletion to cancel."
        case .exportRateLimited:
            return "You can only export your data once per day. Please try again tomorrow."
        }
    }
}

// MARK: - Protocol

protocol ProfileManaging: Sendable {
    func updatePersonalInfo(fullName: String, dateOfBirth: String?) async throws
    func changeEmail(newEmail: String, currentPassword: String) async throws
    func changePassword(currentPassword: String, newPassword: String) async throws
    func getDeletionStatus() async throws -> Date?
    func requestDeletion() async throws
    func cancelDeletion() async throws
    func requestDataExport() async throws -> URL
}

// MARK: - Implementation

final class ProfileServiceImpl: ProfileManaging, Sendable {
    private let supabaseManager: SupabaseManager

    init(supabaseManager: SupabaseManager = .shared) {
        self.supabaseManager = supabaseManager
    }

    func updatePersonalInfo(fullName: String, dateOfBirth: String?) async throws {
        struct Body: Encodable {
            let full_name: String
            let date_of_birth: String?
        }
        try await post(
            path: "api/user/profile",
            method: "PATCH",
            body: Body(full_name: fullName, date_of_birth: dateOfBirth)
        )
    }

    func changeEmail(newEmail: String, currentPassword: String) async throws {
        struct Body: Encodable {
            let newEmail: String
            let currentPassword: String
        }
        try await post(
            path: "api/auth/change-email",
            method: "POST",
            body: Body(newEmail: newEmail, currentPassword: currentPassword)
        )
    }

    func changePassword(currentPassword: String, newPassword: String) async throws {
        struct Body: Encodable {
            let currentPassword: String
            let newPassword: String
        }
        try await post(
            path: "api/auth/change-password",
            method: "POST",
            body: Body(currentPassword: currentPassword, newPassword: newPassword)
        )
    }

    func getDeletionStatus() async throws -> Date? {
        guard let baseURL = SupabaseConfig.apiBaseURL else {
            logger.error("apiBaseURL not configured")
            throw ProfileServiceError.notConfigured
        }
        let url = baseURL.appendingPathComponent("api/account/deletion-status")
        let token = try await supabaseManager.client.auth.session.accessToken
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            logger.error("getDeletionStatus network error: \(error.localizedDescription)")
            throw ProfileServiceError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            logger.error("getDeletionStatus server error")
            return nil
        }

        struct StatusResponse: Decodable {
            let deletion_requested_at: String?
        }
        guard let decoded = try? JSONDecoder().decode(StatusResponse.self, from: data),
              let raw = decoded.deletion_requested_at else {
            return nil
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    func requestDeletion() async throws {
        struct EmptyBody: Encodable {}
        try await post(path: "api/account/request-deletion", method: "POST", body: EmptyBody())
    }

    func cancelDeletion() async throws {
        struct EmptyBody: Encodable {}
        try await post(path: "api/account/cancel-deletion", method: "POST", body: EmptyBody())
    }

    /// Web returns a signed ZIP link (7-day expiry) rather than the bytes, and limits
    /// exports to one per day — surfaced as `.exportRateLimited`.
    func requestDataExport() async throws -> URL {
        guard let baseURL = SupabaseConfig.apiBaseURL else {
            logger.error("apiBaseURL not configured")
            throw ProfileServiceError.notConfigured
        }
        let token = try await supabaseManager.client.auth.session.accessToken
        var request = URLRequest(url: baseURL.appendingPathComponent("api/user/export"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            logger.error("requestDataExport network error: \(error.localizedDescription)")
            throw ProfileServiceError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ProfileServiceError.serverError("Invalid response.")
        }
        if http.statusCode == 429 { throw ProfileServiceError.exportRateLimited }

        struct ExportResponse: Decodable {
            let downloadUrl: URL
        }
        guard (200..<300).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(ExportResponse.self, from: data) else {
            logger.error("requestDataExport failed (\(http.statusCode))")
            throw ProfileServiceError.serverError("Could not generate your data export. Please try again later.")
        }
        return decoded.downloadUrl
    }

    // MARK: - Shared request helper

    private func post<B: Encodable>(path: String, method: String, body: B) async throws {
        guard let baseURL = SupabaseConfig.apiBaseURL else {
            logger.error("apiBaseURL not configured")
            throw ProfileServiceError.notConfigured
        }
        let url = baseURL.appendingPathComponent(path)
        let token = try await supabaseManager.client.auth.session.accessToken

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        logger.debug("ProfileService \(method) \(path)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            logger.error("ProfileService network error: \(error.localizedDescription)")
            throw ProfileServiceError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ProfileServiceError.serverError("Invalid response.")
        }

        if http.statusCode == 401 {
            throw ProfileServiceError.wrongPassword
        }
        if !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "(unreadable)"
            logger.error("ProfileService failed (\(http.statusCode)): \(body, privacy: .private)")
            throw ProfileServiceError.serverError("Request failed. Please try again.")
        }

        logger.info("ProfileService \(method) \(path) succeeded")
    }
}
