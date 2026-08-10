import Foundation
import Observation

@Observable
@MainActor
final class PublicProfileViewModel {
    nonisolated deinit {}

    private let service: PublicProfileManaging
    private let authManager: AuthManaging
    private let targetUserId: String?

    var profile: PlayerProfile?
    var bio: String = ""
    var vanitySlug: String = ""
    var isPublished: Bool = false
    var headerColor: HeaderColor = .slate
    var showAcademics = true
    var showAthletic = true
    var showFilm = true
    var showSchools = true
    var isLoading = false
    var slugError: String?

    var isConfigured: Bool { SupabaseConfig.apiBaseURL != nil }

    init(service: PublicProfileManaging, authManager: AuthManaging, targetUserId: String? = nil) {
        self.service = service
        self.authManager = authManager
        self.targetUserId = targetUserId
    }

    private var token: String? { authManager.session?.accessToken }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let loaded = try await service.fetchProfile(accessToken: token) else { return }
            apply(loaded)
        } catch PublicProfileAPIError.unauthorized {
            let refreshed = await retryAfterRefresh {
                try await self.service.fetchProfile(accessToken: self.token)
            }
            if let refreshed, let profile = refreshed {
                apply(profile)
            }
        } catch {
            // leave state as-is; view shows unconfigured/empty
        }
    }

    func save() async {
        slugError = nil
        validateSlug()
        if slugError != nil { return }
        let payload = UpdateProfilePayload(
            bio: .some(bio.isEmpty ? nil : bio),
            isPublished: isPublished,
            showAcademics: showAcademics, showAthletic: showAthletic,
            showFilm: showFilm, showSchools: showSchools,
            headerColor: headerColor.rawValue,
            vanitySlug: .some(vanitySlug.isEmpty ? nil : vanitySlug)
        )
        do {
            try await service.updateProfile(payload, accessToken: token)
        } catch PublicProfileAPIError.slugTaken {
            slugError = String(localized: "That custom URL is already taken.")
        } catch PublicProfileAPIError.slugInvalid {
            slugError = String(localized: "That custom URL is invalid or reserved.")
        } catch PublicProfileAPIError.unauthorized {
            _ = try? await authManager.refreshSession()
            try? await service.updateProfile(payload, accessToken: token)
        } catch {
            // transient; keep local state
        }
    }

    func validateSlug() {
        switch SlugValidator.validate(vanitySlug) {
        case .empty, .valid: slugError = nil
        case .invalidFormat:
            slugError = String(localized: "Use lowercase letters, numbers, and hyphens only.")
        case .reserved:
            slugError = String(localized: "That custom URL is reserved.")
        }
    }

    var shareURL: URL? {
        guard let profile, let base = SupabaseConfig.apiBaseURL else { return nil }
        let slug = vanitySlug.isEmpty ? profile.hashSlug : vanitySlug
        return base.appendingPathComponent("p").appendingPathComponent(slug)
    }

    private func apply(_ p: PlayerProfile) {
        profile = p
        bio = p.bio ?? ""
        vanitySlug = p.vanitySlug ?? ""
        isPublished = p.isPublished
        headerColor = HeaderColor.from(p.headerColor)
        showAcademics = p.showAcademics
        showAthletic = p.showAthletic
        showFilm = p.showFilm
        showSchools = p.showSchools
    }

    @discardableResult
    private func retryAfterRefresh<T>(_ op: () async throws -> T) async -> T? {
        do {
            _ = try await authManager.refreshSession()
            return try await op()
        } catch {
            return nil
        }
    }
}
