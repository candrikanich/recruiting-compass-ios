import Foundation
@testable import TheRecruitingCompass

private struct MockVideoLinksUnimplementedError: Error {}

/// Minimal `VideoLinksManaging` mock. Only `fetchVideoLinks` is stubbed for
/// `PublicProfileViewModel.assembleCard()`; write methods are unused by that call path.
final class MockVideoLinksService: VideoLinksManaging, @unchecked Sendable {
    var stubbedVideoLinks: [VideoLink] = []
    var errorToThrow: Error?

    func fetchVideoLinks(userId: String) async throws -> [VideoLink] {
        if let errorToThrow { throw errorToThrow }
        return stubbedVideoLinks
    }

    func createVideoLink(_ request: VideoLinkCreateRequest) async throws -> VideoLink {
        throw MockVideoLinksUnimplementedError()
    }

    func updateVideoLink(id: String, userId: String, _ request: VideoLinkUpdateRequest) async throws -> VideoLink {
        throw MockVideoLinksUnimplementedError()
    }

    func deleteVideoLink(id: String, userId: String) async throws {}
}
